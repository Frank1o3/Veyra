//! Disk layout planning.
//!
//! This module only defines and reads disk state. It must never perform
//! destructive operations -- partitioning, formatting, and mounting
//! belong to `install`, which acts on a `DiskLayout` only during the
//! installation phase, never while the user is still navigating
//! configuration screens.

use serde::{Deserialize, Serialize};
use std::process::Command;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiskLayout {
    pub target_disk: String, // e.g. "/dev/nvme0n1"
    pub scheme: PartitionScheme,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum PartitionScheme {
    /// Wipe the target disk and create a fresh EFI System Partition + a
    /// single Btrfs partition for everything else (root, home, etc. as
    /// subvolumes). This is the only scheme worth supporting until the
    /// bootable-install path itself works end to end.
    ErasePlainBtrfs { esp_size_mib: u32 },
    // Dual-boot / manual partitioning schemes are deliberately not
    // modeled yet -- adding them before the erase-and-install path is
    // proven would be exactly the kind of premature abstraction the
    // project's early stage doesn't call for.
}

/// A disk as reported by the kernel/udev, before any layout decision has
/// been made. Used to populate the disk-selection screen.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AvailableDisk {
    pub device_path: String, // e.g. "/dev/nvme0n1"
    pub size_bytes: u64,
    pub model: Option<String>,
}

impl AvailableDisk {
    /// Human-readable size, e.g. "512.1 GB". Uses decimal (GB, not GiB)
    /// units to match what's printed on the drive's own label and what
    /// most partitioning tools show, avoiding a size that looks like it
    /// doesn't match the hardware.
    pub fn size_human(&self) -> String {
        const UNITS: [&str; 5] = ["B", "kB", "MB", "GB", "TB"];
        let mut size = self.size_bytes as f64;
        let mut unit_index = 0;
        while size >= 1000.0 && unit_index < UNITS.len() - 1 {
            size /= 1000.0;
            unit_index += 1;
        }
        format!("{:.1} {}", size, UNITS[unit_index])
    }

    pub fn label(&self) -> String {
        match &self.model {
            Some(model) => format!("{} - {} ({})", self.device_path, model, self.size_human()),
            None => format!("{} ({})", self.device_path, self.size_human()),
        }
    }
}

/// Raw shape of one `lsblk --json` entry for the columns we request.
/// Kept private -- callers get `AvailableDisk`, not this.
#[derive(Debug, Deserialize)]
struct LsblkDevice {
    path: Option<String>,
    size: Option<u64>,
    model: Option<String>,
    #[serde(rename = "type")]
    device_type: Option<String>,
}

#[derive(Debug, Deserialize)]
struct LsblkOutput {
    blockdevices: Vec<LsblkDevice>,
}

/// Lists block devices suitable as install targets. Non-destructive: this
/// only reads state via `lsblk -J -b -o PATH,SIZE,MODEL,TYPE`, using
/// structured JSON output rather than parsing lsblk's human-readable
/// column layout, and filters to `TYPE == "disk"` so partitions,
/// loop devices, and device-mapper entries don't show up as install
/// targets.
pub fn list_available_disks() -> Result<Vec<AvailableDisk>, DiskError> {
    let output = Command::new("lsblk")
        .args(["-J", "-b", "-o", "PATH,SIZE,MODEL,TYPE"])
        .output()
        .map_err(DiskError::LsblkSpawnFailed)?;

    if !output.status.success() {
        return Err(DiskError::LsblkExitedWithError(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }

    let parsed: LsblkOutput =
        serde_json::from_slice(&output.stdout).map_err(DiskError::MalformedJson)?;

    let disks = parsed
        .blockdevices
        .into_iter()
        .filter(|d| d.device_type.as_deref() == Some("disk"))
        .filter_map(|d| {
            Some(AvailableDisk {
                device_path: d.path?,
                size_bytes: d.size.unwrap_or(0),
                model: d.model.filter(|m| !m.trim().is_empty()),
            })
        })
        .collect();

    Ok(disks)
}

#[derive(Debug, Error)]
pub enum DiskError {
    #[error("failed to run lsblk: {0}")]
    LsblkSpawnFailed(#[source] std::io::Error),
    #[error("lsblk exited with an error: {0}")]
    LsblkExitedWithError(String),
    #[error("failed to parse lsblk output: {0}")]
    MalformedJson(#[source] serde_json::Error),
}
