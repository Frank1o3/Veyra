//! Installation execution.
//!
//! Everything in this module is destructive and must only run during the
//! explicit installation phase, after the user has confirmed the final
//! plan on the Install screen.

use std::path::Path;

use crate::disk;
use crate::state::InstallState;

#[derive(Debug, thiserror::Error)]
pub enum InstallError {
    #[error("installation state is incomplete: missing {0:?}")]
    IncompleteState(Vec<&'static str>),
    #[error("disk setup failed: {0}")]
    Disk(#[from] crate::disk::DiskError),
    #[error("bootloader setup failed: {0}")]
    Bootloader(#[from] crate::bootloader::BootloaderError),
    #[error("post-install setup failed: {0}")]
    PostInstall(#[from] crate::postinstall::PostInstallError),
    #[error("pacstrap failed: {0}")]
    Pacstrap(String),
    #[error("failed to write {path}: {source}")]
    WriteFailed {
        path: String,
        #[source]
        source: std::io::Error,
    },
}

const BASE_PACKAGES: &[&str] = &[
    "base",
    "base-devel", // needed for the AUR/makepkg step in postinstall
    "linux-cachyos",
    "linux-firmware",
    "btrfs-progs",
    "limine",
    "networkmanager",
    "sudo",
    "git",
    "nano",
    "zsh",
];

pub fn run(state: &InstallState) -> Result<(), InstallError> {
    if !state.is_ready_for_install() {
        return Err(InstallError::IncompleteState(state.missing_fields()));
    }

    // Unwraps below are safe: is_ready_for_install() just confirmed
    // every field this touches is Some.
    let disk_layout = state.disk_layout.as_ref().unwrap();
    let profile = state.hardware_profile.as_ref().unwrap();
    let username = state.account.username.as_ref().unwrap();
    let password = state.account.password.as_ref().unwrap();
    let hostname = state.account.hostname.as_ref().unwrap();

    let target = disk::partition_and_format(disk_layout)?;

    pacstrap(&target.mountpoint, profile)?;
    write_fstab(&target.mountpoint)?;
    configure_system(&target.mountpoint, hostname, &state.system)?;
    create_account(&target.mountpoint, username, password)?;

    crate::bootloader::install_and_configure(&target.mountpoint, &target.root_device)?;
    crate::postinstall::run(&target.mountpoint, "veyra-build")?;

    let unmount_failures = disk::unmount_target();
    if !unmount_failures.is_empty() {
        // Install succeeded even if cleanup didn't -- don't fail the
        // whole install over a stuck unmount, just surface it.
        eprintln!("warning: failed to unmount some targets: {unmount_failures:?}");
    }

    Ok(())
}

fn pacstrap(
    mountpoint: &Path,
    profile: &crate::profiles::HardwareProfile,
) -> Result<(), InstallError> {
    let mut packages: Vec<&str> = BASE_PACKAGES.to_vec();
    packages.extend(profile.graphics_packages());
    packages.extend(profile.microcode_packages());

    let mut args = vec!["-c", mountpoint.to_str().unwrap_or("/mnt")];
    args.extend(packages);

    let status = std::process::Command::new("pacstrap")
        .args(&args)
        .status()
        .map_err(|e| InstallError::Pacstrap(e.to_string()))?;

    if !status.success() {
        return Err(InstallError::Pacstrap(format!(
            "pacstrap exited with {status}"
        )));
    }
    Ok(())
}

fn write_fstab(mountpoint: &Path) -> Result<(), InstallError> {
    let output = std::process::Command::new("genfstab")
        .args(["-U", mountpoint.to_str().unwrap_or("/mnt")])
        .output()
        .map_err(|e| InstallError::WriteFailed {
            path: "fstab (genfstab spawn)".to_string(),
            source: e,
        })?;

    let fstab_path = mountpoint.join("etc/fstab");
    std::fs::write(&fstab_path, output.stdout).map_err(|source| InstallError::WriteFailed {
        path: fstab_path.display().to_string(),
        source,
    })
}

fn configure_system(
    mountpoint: &Path,
    hostname: &str,
    system: &crate::state::SystemConfig,
) -> Result<(), InstallError> {
    std::fs::write(mountpoint.join("etc/hostname"), format!("{hostname}\n")).map_err(|source| {
        InstallError::WriteFailed {
            path: "etc/hostname".to_string(),
            source,
        }
    })?;

    if let Some(locale) = &system.locale {
        let locale_gen_path = mountpoint.join("etc/locale.gen");
        let existing = std::fs::read_to_string(&locale_gen_path).unwrap_or_default();
        // Uncomment the requested locale line if present, rather than
        // blindly appending -- locale.gen ships with every supported
        // locale pre-listed but commented out.
        let updated = existing
            .lines()
            .map(|line| {
                if line
                    .trim_start_matches('#')
                    .trim_start()
                    .starts_with(locale.as_str())
                {
                    line.trim_start_matches('#').to_string()
                } else {
                    line.to_string()
                }
            })
            .collect::<Vec<_>>()
            .join("\n");
        std::fs::write(&locale_gen_path, updated).map_err(|source| InstallError::WriteFailed {
            path: locale_gen_path.display().to_string(),
            source,
        })?;
        std::fs::write(
            mountpoint.join("etc/locale.conf"),
            format!("LANG={locale}\n"),
        )
        .map_err(|source| InstallError::WriteFailed {
            path: "etc/locale.conf".to_string(),
            source,
        })?;
        disk::run_in_chroot(mountpoint, "locale-gen", &[])?;
    }

    if let Some(tz) = &system.timezone {
        disk::run_in_chroot(
            mountpoint,
            "ln",
            &[
                "-sf",
                &format!("/usr/share/zoneinfo/{tz}"),
                "/etc/localtime",
            ],
        )?;
    }

    disk::run_in_chroot(mountpoint, "mkinitcpio", &["-P"])?;

    Ok(())
}

fn create_account(mountpoint: &Path, username: &str, password: &str) -> Result<(), InstallError> {
    disk::run_in_chroot(
        mountpoint,
        "useradd",
        &["-m", "-G", "wheel", "-s", "/bin/zsh", username],
    )?;
    disk::chroot_set_password(mountpoint, username, password)?;
    Ok(())
}
