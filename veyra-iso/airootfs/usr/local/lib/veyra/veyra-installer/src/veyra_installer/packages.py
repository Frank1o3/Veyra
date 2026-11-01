"""Package selection, keyring/mirror preparation and pacstrap."""
from __future__ import annotations

from pathlib import Path

from .config import BASE_PACKAGES, KERNEL_PROFILES, MOUNT
from .hardware import Hardware
from .shell import InstallerError, run
from .ui import console, step


def build_package_list(hw: Hardware) -> list[str]:
    """Packages for the online stage; kernels are installed in the cache stage."""
    packages = [p for p in BASE_PACKAGES + hw.extra_packages
                if not p.startswith("linux-cachyos")]
    return list(dict.fromkeys(packages))


def prepare_keys_and_mirrors(hw: Hardware, profile: str) -> None:
    step("Package keys and mirrors")
    run("systemctl start pacman-init.service", check=False, log=False)
    if not (
        Path("/etc/pacman.d/gnupg/pubring.kbx").exists()
        or Path("/etc/pacman.d/gnupg/pubring.gpg").exists()
    ):
        run("pacman-key --init")
    run("pacman-key --populate archlinux cachyos")

    mirrorlist = Path("/etc/pacman.d/mirrorlist")
    backup = Path("/etc/pacman.d/mirrorlist.bak")
    backup.write_bytes(mirrorlist.read_bytes())
    console.print("Ranking Arch mirrors (this can take a minute)...")
    rc = run(
        [
            "cachyos-rate-mirrors"
        ],
        check=False,
    )
    if rc != 0:
        console.print("[yellow]Mirror ranking failed; keeping the default mirrorlist.[/]")
        mirrorlist.write_bytes(backup.read_bytes())

    if profile not in KERNEL_PROFILES:
        raise ValueError(f"Unknown CachyOS package profile: {profile}")
    _, _, repo_suffix = KERNEL_PROFILES[profile]
    conf = Path("/etc/pacman.conf")
    text = conf.read_text()
    # Keep the standard CachyOS repository, and add the optimized repo set.
    # Their order makes optimized builds win when package names overlap.
    optimized = ""
    if repo_suffix:
        mirrorlist = (
            "cachyos-v3-mirrorlist" if repo_suffix == "-v3"
            else "cachyos-v4-mirrorlist"
        )
        for repo in ("cachyos" + repo_suffix,
                     "cachyos-core" + repo_suffix,
                     "cachyos-extra" + repo_suffix):
            optimized += f"[{repo}]\nInclude = /etc/pacman.d/{mirrorlist}\n\n"
    text = text.replace("[cachyos]\n", optimized + "[cachyos]\n", 1)
    conf.write_text(text)
    console.print(f"Using {KERNEL_PROFILES[profile][0]} package repositories.")
    run("pacman -Syy --noconfirm")


def install_kernel(profile: str, hw: Hardware) -> None:
    """Install cached kernel archives before pacstrap's online package stage."""
    step("Installing the selected kernel from the ISO cache")
    if profile not in KERNEL_PROFILES:
        raise InstallerError(f"Unknown CachyOS package profile: {profile}")
    cache = Path("/usr/share/veyra/kernel-cache") / profile
    archives = sorted(cache.glob("*.pkg.tar.zst"))
    if not archives:
        raise InstallerError(
            f"The ISO has no cached kernel packages for {profile}. "
            "Rebuild it with build.sh so the kernel cache is staged."
        )
    # The archives include the selected kernels and their dependency closure;
    # -U installs them as local package files without fetching kernel payloads.
    run([
        "pacstrap", "-C", "/etc/pacman.conf", "-U", "-P", MOUNT,
        *(str(archive) for archive in archives),
    ])


def install_base(packages: list[str]) -> None:
    step("Installing remaining packages from the network (this takes a while)")
    run(["pacstrap", MOUNT, *packages])
