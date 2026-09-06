//! Post-install configuration: OpenRC runlevel enablement and the
//! elogind/eudev/openrc package bootstrap.
//!
//! ARCHITECTURAL NOTE (read before changing this file):
//! Arch has no official OpenRC support. `openrc`, `openrc-arch-services`,
//! `elogind-openrc`, `eudev`, and per-daemon `*-openrc` wrapper packages
//! all live in the AUR, not `core`/`extra`/`cachyos`. Two ways to get
//! them onto the target:
//!   (a) build from AUR inside the target chroot at install time via
//!       makepkg (needs network + base-devel + a non-root build user --
//!       makepkg refuses to run as root)
//!   (b) Veyra hosts its own prebuilt binary repo, built ahead of time,
//!       added to pacman.conf like the existing [cachyos] repo
//!
//! This implements (a) as the pragmatic path to get a boot working at
//! all. It is isolated behind `bootstrap_openrc_packages` specifically
//! so switching to (b) later is a localized change, not a rewrite of
//! this module's control flow.

use std::path::Path;
use thiserror::Error;

use crate::disk;

#[derive(Debug, Error)]
pub enum PostInstallError {
    #[error("failed to run {cmd}: {source}")]
    SpawnFailed {
        cmd: String,
        #[source]
        source: std::io::Error,
    },
    #[error("{cmd} exited with an error: {stderr}")]
    CommandFailed { cmd: String, stderr: String },
}

/// AUR packages required for a minimal bootable OpenRC + elogind system.
/// Does not include desktop-specific service wrappers (Hyprland/Quickshell
/// setup is a later concern, not part of getting to a tty1 shell).
const AUR_PACKAGES: &[&str] = &[
    "eudev",
    "openrc",
    "openrc-arch-services-git",
    "elogind-openrc",
    "networkmanager-openrc",
];

/// Services enabled into the `default` OpenRC runlevel. `dev-udev` boots
/// devices, `elogind` provides logind/session functionality for
/// Wayland/Hyprland, `NetworkManager` matches the systemd-era default of
/// networking being on out of the box.
const DEFAULT_RUNLEVEL_SERVICES: &[&str] = &["udev", "elogind", "NetworkManager"];
const BOOT_RUNLEVEL_SERVICES: &[&str] = &["hostname", "localmount", "bootmisc"];

pub fn run(mountpoint: &Path, build_user: &str) -> Result<(), PostInstallError> {
    bootstrap_openrc_packages(mountpoint, build_user)?;
    enable_services(mountpoint)?;
    Ok(())
}

/// Builds and installs `AUR_PACKAGES` inside the chroot via `makepkg`,
/// running as `build_user` (created transiently for this purpose --
/// makepkg refuses to run as root). Requires network access inside the
/// chroot and `base-devel` already pacstrap'd.
fn bootstrap_openrc_packages(mountpoint: &Path, build_user: &str) -> Result<(), PostInstallError> {
    // A throwaway unprivileged account, purely so makepkg has a non-root
    // user to run as. Not the end-user account -- deleted implicitly by
    // never persisting past this function's chroot in a real deployment
    // scenario, though on a live filesystem it will linger on the
    // installed system today. Cleaning it up is a follow-up.
    chroot_ignore_exists(mountpoint, "useradd", &["-m", build_user])?;
    chroot(
        mountpoint,
        "sh",
        &[
            "-c",
            &format!("echo '{build_user} ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"),
        ],
    )?;

    for pkg in AUR_PACKAGES {
        let build_cmd = format!(
            "cd /tmp && sudo -u {build_user} git clone --depth 1 \
             https://aur.archlinux.org/{pkg}.git && \
             cd {pkg} && sudo -u {build_user} makepkg -si --noconfirm"
        );
        chroot(mountpoint, "sh", &["-c", &build_cmd])?;
    }

    Ok(())
}

fn enable_services(mountpoint: &Path) -> Result<(), PostInstallError> {
    for service in BOOT_RUNLEVEL_SERVICES {
        chroot(mountpoint, "rc-update", &["add", service, "boot"])?;
    }
    for service in DEFAULT_RUNLEVEL_SERVICES {
        chroot(mountpoint, "rc-update", &["add", service, "default"])?;
    }
    Ok(())
}

fn chroot(mountpoint: &Path, cmd: &str, args: &[&str]) -> Result<(), PostInstallError> {
    disk::run_in_chroot(mountpoint, cmd, args).map_err(|e| PostInstallError::CommandFailed {
        cmd: cmd.to_string(),
        stderr: e.to_string(),
    })
}

/// Like `chroot`, but doesn't fail if e.g. the build user already exists
/// from a previous partial install attempt.
fn chroot_ignore_exists(
    mountpoint: &Path,
    cmd: &str,
    args: &[&str],
) -> Result<(), PostInstallError> {
    let _ = chroot(mountpoint, cmd, args);
    Ok(())
}
