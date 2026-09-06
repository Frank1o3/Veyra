//! Bootloader configuration (Limine).
//!
//! Limine's on-disk config syntax has changed across major versions
//! (the old INI-style `limine.cfg` vs. the newer keyval `limine.conf`).
//! This targets the current keyval format shipped by the `limine`
//! package in Arch's `extra` repo as of writing -- verify against
//! `pacman -Qi limine` on the target before relying on this unchanged
//! across a Limine upgrade.
//!
//! Does NOT yet coordinate with Btrfs snapshots -- see the project's
//! rollback notes. A snapshot of the root subvolume does not capture
//! the ESP, so a rollback that changes the kernel/initramfs currently
//! has no matching mechanism to roll back what's on the ESP. That
//! coordination is a follow-up, not solved here.

use std::path::Path;
use std::process::Command;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum BootloaderError {
    #[error("failed to run {cmd}: {source}")]
    SpawnFailed {
        cmd: String,
        #[source]
        source: std::io::Error,
    },
    #[error("{cmd} exited with an error: {stderr}")]
    CommandFailed { cmd: String, stderr: String },
    #[error("failed to write {path}: {source}")]
    WriteFailed {
        path: String,
        #[source]
        source: std::io::Error,
    },
}

/// Installs Limine's UEFI boot binary onto the ESP and writes a minimal
/// `limine.conf` pointing at the just-installed kernel/initramfs.
///
/// `mountpoint` is the installed system's root (e.g. `/mnt`); the ESP is
/// assumed mounted at `{mountpoint}/boot` per `disk::mount_target`.
pub fn install_and_configure(mountpoint: &Path, root_device: &str) -> Result<(), BootloaderError> {
    let boot_dir = mountpoint.join("boot");
    let efi_boot_dir = boot_dir.join("EFI/BOOT");

    std::fs::create_dir_all(&efi_boot_dir).map_err(|source| BootloaderError::WriteFailed {
        path: efi_boot_dir.display().to_string(),
        source,
    })?;

    // The `limine` package (pacstrap'd as part of install::run) ships its
    // EFI binary under /usr/share/limine inside the target. Using the
    // EFI\BOOT\BOOTX64.EFI fallback path (rather than registering an
    // NVRAM boot entry via efibootmgr) is deliberate: it works
    // unconditionally across firmware that mishandles NVRAM entries
    // (common in VMs and some laptops), at the cost of not showing a
    // named "Veyra" entry in the firmware's boot menu. Revisit once
    // basic boot is proven reliable.
    run_checked(
        "cp",
        &[
            path_str(&mountpoint.join("usr/share/limine/BOOTX64.EFI")),
            path_str(&efi_boot_dir.join("BOOTX64.EFI")),
        ],
    )?;

    let root_uuid = blkid_uuid(root_device)?;

    // Btrfs subvol=@ must be specified so Limine's kernel cmdline mounts
    // the correct subvolume as /, matching disk::mount_target's layout.
    let config = format!(
        "timeout: 5\n\n\
         /Veyra OS\n\
         \tprotocol: linux\n\
         \tkernel_path: boot():/boot/vmlinuz-linux-cachyos\n\
         \tmodule_path: boot():/boot/initramfs-linux-cachyos.img\n\
         \tkernel_cmdline: root=UUID={root_uuid} rootflags=subvol=@ rw\n"
    );

    std::fs::write(boot_dir.join("limine.conf"), config).map_err(|source| {
        BootloaderError::WriteFailed {
            path: boot_dir.join("limine.conf").display().to_string(),
            source,
        }
    })?;

    Ok(())
}

fn blkid_uuid(device: &str) -> Result<String, BootloaderError> {
    let output = Command::new("blkid")
        .args(["-s", "UUID", "-o", "value", device])
        .output()
        .map_err(|source| BootloaderError::SpawnFailed {
            cmd: "blkid".to_string(),
            source,
        })?;
    if !output.status.success() {
        return Err(BootloaderError::CommandFailed {
            cmd: "blkid".to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn path_str(p: &Path) -> &str {
    p.to_str().unwrap_or_default()
}

fn run_checked(cmd: &str, args: &[&str]) -> Result<(), BootloaderError> {
    let output =
        Command::new(cmd)
            .args(args)
            .output()
            .map_err(|source| BootloaderError::SpawnFailed {
                cmd: cmd.to_string(),
                source,
            })?;
    if !output.status.success() {
        return Err(BootloaderError::CommandFailed {
            cmd: cmd.to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
        });
    }
    Ok(())
}
