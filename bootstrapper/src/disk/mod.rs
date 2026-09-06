//! Disk layout planning.
//!
//! This module only defines and reads disk state. It must never perform
//! destructive operations -- partitioning, formatting, and mounting
//! belong to `install`, which acts on a `DiskLayout` only during the
//! installation phase, never while the user is still navigating
//! configuration screens.

use serde::{Deserialize, Serialize};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::process::Stdio;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiskLayout {
    pub target_disk: String, // e.g. "/dev/nvme0n1"
    pub scheme: PartitionScheme,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PartitionScheme {
    ErasePlainBtrfs { esp_size_mib: u32 },
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
    #[error("failed to read/write {path}: {source}")]
    ReadFailed {
        path: String,
        #[source]
        source: std::io::Error,
    },
    #[error("failed to run {0}: {1}")]
    CommandSpawnFailed(String, #[source] std::io::Error),
    #[error("{0} exited with an error: {1}")]
    CommandFailed(String, String),
}

// --- Everything below this line is new: actual partitioning/formatting. ---
// `list_available_disks` above stays read-only. Everything here is
// destructive and must only be called from `install::run`, never from a
// screen handler.

/// A fully partitioned, formatted, and mounted target, ready for pacstrap.
/// Built once by `partition_and_format` and threaded through the rest of
/// the install pipeline (fstab generation, chroot config, bootloader).
#[derive(Debug, Clone)]
pub struct TargetLayout {
    pub esp_device: String,
    pub root_device: String,
    pub mountpoint: PathBuf,
}

const MOUNTPOINT: &str = "/mnt";

/// Partitions `layout.target_disk` (GPT: ESP + Btrfs), formats both,
/// creates the Btrfs subvolume layout, and mounts everything under
/// `/mnt`. This is the single destructive entry point for disk setup --
/// nothing before this point in the install pipeline should have touched
/// the disk.
pub fn partition_and_format(layout: &DiskLayout) -> Result<TargetLayout, DiskError> {
    let PartitionScheme::ErasePlainBtrfs { esp_size_mib } = layout.scheme;
    let disk = &layout.target_disk;
    let suffix = partition_suffix(disk);

    let esp_device = format!("{disk}{suffix}1");
    let root_device = format!("{disk}{suffix}2");

    run_checked("sgdisk", &["--zap-all", disk])?;
    run_checked(
        "sgdisk",
        &[
            &format!("--new=1:0:+{esp_size_mib}MiB"),
            "--typecode=1:ef00",
            "--change-name=1:EFI",
            disk,
        ],
    )?;
    run_checked(
        "sgdisk",
        &[
            "--new=2:0:0",
            "--typecode=2:8300",
            "--change-name=2:veyra_root",
            disk,
        ],
    )?;

    // Let the kernel/udev catch up on the new partition table before we
    // try to format devices that may not have appeared yet.
    run_checked("partprobe", &[disk])?;
    run_checked("udevadm", &["settle"])?;

    run_checked("mkfs.fat", &["-F32", "-n", "EFI", &esp_device])?;
    run_checked("mkfs.btrfs", &["-f", "-L", "veyra_root", &root_device])?;

    create_subvolumes(&root_device)?;
    mount_target(&esp_device, &root_device)?;

    Ok(TargetLayout {
        esp_device,
        root_device,
        mountpoint: PathBuf::from(MOUNTPOINT),
    })
}

/// nvme/mmcblk devices need a `p` before the partition number
/// (`/dev/nvme0n1p1`); traditional `sdX`/`vdX` devices don't
/// (`/dev/sda1`).
fn partition_suffix(disk: &str) -> &'static str {
    let base = disk.rsplit('/').next().unwrap_or(disk);
    if base.starts_with("nvme") || base.starts_with("mmcblk") {
        "p"
    } else {
        ""
    }
}

/// Mounts the fresh Btrfs filesystem once at a scratch point to create
/// the subvolume layout, then unmounts -- the real mounts (with the
/// right `subvol=` options) happen in `mount_target`.
fn create_subvolumes(root_device: &str) -> Result<(), DiskError> {
    const SCRATCH: &str = "/mnt/veyra-subvol-scratch";
    std::fs::create_dir_all(SCRATCH).map_err(|source| DiskError::ReadFailed {
        path: SCRATCH.to_string(),
        source,
    })?;

    run_checked("mount", &[root_device, SCRATCH])?;

    let result = (|| -> Result<(), DiskError> {
        for subvol in ["@", "@home", "@snapshots", "@var_log"] {
            run_checked(
                "btrfs",
                &["subvolume", "create", &format!("{SCRATCH}/{subvol}")],
            )?;
        }
        Ok(())
    })();

    // Always try to unmount, even if a subvolume create failed, so we
    // don't leave a stray mount behind.
    let _ = run_checked("umount", &[SCRATCH]);
    result
}

fn mount_target(esp_device: &str, root_device: &str) -> Result<(), DiskError> {
    let opts = "noatime,compress=zstd:3,space_cache=v2";

    mkdir(MOUNTPOINT)?;
    run_checked(
        "mount",
        &["-o", &format!("{opts},subvol=@"), root_device, MOUNTPOINT],
    )?;

    for (dir, subvol) in [
        ("home", "@home"),
        (".snapshots", "@snapshots"),
        ("var/log", "@var_log"),
    ] {
        let target = format!("{MOUNTPOINT}/{dir}");
        mkdir(&target)?;
        run_checked(
            "mount",
            &[
                "-o",
                &format!("{opts},subvol={subvol}"),
                root_device,
                &target,
            ],
        )?;
    }

    let esp_target = format!("{MOUNTPOINT}/boot");
    mkdir(&esp_target)?;
    run_checked("mount", &[esp_device, &esp_target])?;

    Ok(())
}

fn mkdir(path: &str) -> Result<(), DiskError> {
    std::fs::create_dir_all(path).map_err(|source| DiskError::ReadFailed {
        path: path.to_string(),
        source,
    })
}

/// Runs `cmd args...` with a structured argument list (never a shell
/// string), returning an error with captured stderr on non-zero exit.
fn run_checked(cmd: &str, args: &[&str]) -> Result<(), DiskError> {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .map_err(|source| DiskError::CommandSpawnFailed(cmd.to_string(), source))?;
    if !output.status.success() {
        return Err(DiskError::CommandFailed(
            format!("{cmd} {args:?}"),
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }
    Ok(())
}

/// Runs `arch-chroot <mountpoint> cmd args...`.
pub fn run_in_chroot(mountpoint: &Path, cmd: &str, args: &[&str]) -> Result<(), DiskError> {
    let mut full_args = vec![mountpoint.to_str().unwrap_or(MOUNTPOINT), cmd];
    full_args.extend_from_slice(args);
    run_checked("arch-chroot", &full_args)
}

/// Runs `chpasswd` inside the chroot, feeding `user:password` over
/// stdin rather than as a CLI argument or shell-interpolated string, so
/// the plaintext password never appears in argv or shell history.
pub fn chroot_set_password(
    mountpoint: &Path,
    username: &str,
    password: &str,
) -> Result<(), DiskError> {
    let mut child = Command::new("arch-chroot")
        .arg(mountpoint)
        .arg("chpasswd")
        .stdin(Stdio::piped())
        .spawn()
        .map_err(DiskError::LsblkSpawnFailed)?;

    if let Some(stdin) = child.stdin.as_mut() {
        writeln!(stdin, "{username}:{password}").map_err(|source| DiskError::ReadFailed {
            path: "chpasswd stdin".to_string(),
            source,
        })?;
    }

    let status = child.wait().map_err(DiskError::LsblkSpawnFailed)?;
    if !status.success() {
        return Err(DiskError::LsblkExitedWithError(
            "chpasswd failed".to_string(),
        ));
    }
    Ok(())
}

/// Unmounts everything under `/mnt`, deepest-first, at the end of
/// install. Best-effort: logs failures via the returned Vec rather than
/// aborting partway, since a stuck unmount shouldn't hide the fact that
/// install otherwise succeeded.
pub fn unmount_target() -> Vec<String> {
    let mut failures = Vec::new();
    for target in [
        format!("{MOUNTPOINT}/boot"),
        format!("{MOUNTPOINT}/var/log"),
        format!("{MOUNTPOINT}/.snapshots"),
        format!("{MOUNTPOINT}/home"),
        MOUNTPOINT.to_string(),
    ] {
        if let Err(e) = run_checked("umount", &[&target]) {
            failures.push(format!("{target}: {e}"));
        }
    }
    failures
}
