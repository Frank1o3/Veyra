"""Package selection, keyring/mirror preparation and pacstrap."""
from __future__ import annotations

from pathlib import Path

from .config import BASE_PACKAGES, KERNEL_PROFILES, MOUNT
from .hardware import Hardware
from .shell import InstallerError, run
from .ui import console, step


KERNEL_CACHE_PACKAGES = {
    "linux-firmware", "intel-ucode", "amd-ucode", "mesa", "vulkan-intel",
    "intel-media-driver", "vulkan-radeon", "libva-mesa-driver", "dkms",
    "nvidia-open-dkms", "nvidia-580xx-dkms", "nvidia-utils",
    "lib32-nvidia-utils", "nvidia-580xx-utils", "lib32-nvidia-580xx-utils",
    "vulkan-icd-loader", "lib32-vulkan-icd-loader",
    "linux-cachyos", "linux-cachyos-lts", "linux-cachyos-headers",
}


def build_package_list(hw: Hardware, profile: str) -> list[str]:
    """Packages outside the separately cached kernel and hardware stack."""
    packages = [p for p in BASE_PACKAGES + hw.extra_packages
                if p not in KERNEL_CACHE_PACKAGES]
    if profile in {"v3", "v4", "znver4"}:
        packages.append(
            "cachyos-v3-mirrorlist" if profile == "v3"
            else "cachyos-v4-mirrorlist"
        )
    return list(dict.fromkeys(packages))


def prepare_keys_and_mirrors(hw: Hardware, profile: str, offline: bool = False) -> None:
    step("Package keys and mirrors")
    run("systemctl start pacman-init.service", check=False, log=False)
    if not (
        Path("/etc/pacman.d/gnupg/pubring.kbx").exists()
        or Path("/etc/pacman.d/gnupg/pubring.gpg").exists()
    ):
        run("pacman-key --init")
    run("pacman-key --populate archlinux cachyos")

    if profile not in KERNEL_PROFILES:
        raise ValueError(f"Unknown CachyOS package profile: {profile}")
    _, _, repo_suffix = KERNEL_PROFILES[profile]
    if not offline:
        mirrorlist = Path("/etc/pacman.d/mirrorlist")
        backup = Path("/etc/pacman.d/mirrorlist.bak")
        backup.write_bytes(mirrorlist.read_bytes())
        console.print("Ranking Arch mirrors (this can take a minute)...")
        rc = run(["cachyos-rate-mirrors"], check=False)
        if rc != 0:
            console.print("[yellow]Mirror ranking failed; keeping the default mirrorlist.[/]")
            mirrorlist.write_bytes(backup.read_bytes())
    if repo_suffix and not offline:
        mirrorlist_package = (
            "cachyos-v3-mirrorlist" if repo_suffix == "-v3"
            else "cachyos-v4-mirrorlist"
        )
        run(["pacman", "-S", "--needed", "--noconfirm", mirrorlist_package])
    conf = Path("/etc/pacman.conf")
    text = conf.read_text()
    # Keep the standard CachyOS repository, and add the optimized repo set.
    # Their order makes optimized builds win when package names overlap.
    optimized = ""
    if repo_suffix:
        mirrorlist_file = (
            "cachyos-v3-mirrorlist" if repo_suffix == "-v3"
            else "cachyos-v4-mirrorlist"
        )
        for repo in ("cachyos" + repo_suffix,
                     "cachyos-core" + repo_suffix,
                     "cachyos-extra" + repo_suffix):
            optimized += f"[{repo}]\nInclude = /etc/pacman.d/{mirrorlist_file}\n\n"
    text = text.replace("[cachyos]\n", optimized + "[cachyos]\n", 1)
    conf.write_text(text)
    console.print(f"Using {KERNEL_PROFILES[profile][0]} package repositories.")
    if offline:
        console.print("Using package databases and archives from the ISO snapshot.")
    else:
        run("pacman -Syy --noconfirm")


def _cache_repo_name(profile: str) -> str:
    return {"generic": "veyra-kernel", "v3": "veyra-kernel-v3",
            "v4": "veyra-kernel-v4", "znver4": "veyra-kernel-znver4"}[profile]


def cached_package_archives(cache: Path) -> list[Path]:
    """Return cached package archives in stable order for inspection/tools."""
    return sorted(cache.glob("*.pkg.tar.zst"))


def _offline_pacman_config(profile: str) -> Path:
    validate_offline_cache(profile)
    root = Path("/usr/share/veyra")
    kernel_repo = root / "kernel-cache" / profile
    package_repo = root / "package-cache"
    kernel_name = _cache_repo_name(profile)
    config = Path("/tmp/veyra-offline-pacman.conf")
    config.write_text(
        "[options]\nArchitecture = auto\nSigLevel = Required DatabaseOptional\n"
        "LocalFileSigLevel = Optional\n\n"
        f"[{kernel_name}]\nServer = file://{kernel_repo}\n\n"
        f"[veyra-packages]\nServer = file://{package_repo}\n"
    )
    return config


def validate_offline_cache(profile: str) -> None:
    if profile not in KERNEL_PROFILES:
        raise InstallerError(f"Unknown CachyOS package profile: {profile}")
    root = Path("/usr/share/veyra")
    kernel_repo = root / "kernel-cache" / profile
    package_repo = root / "package-cache"
    kernel_name = _cache_repo_name(profile)
    for directory, repo in ((kernel_repo, kernel_name),
                            (package_repo, "veyra-packages")):
        if not (directory / f"{repo}.db.tar.gz").is_file():
            raise InstallerError(
                f"The ISO is missing the {repo} offline package database. "
                "Rebuild it with build.sh to create complete package caches."
            )
        if not (directory / f"{repo}.files.tar.gz").is_file():
            raise InstallerError(
                f"The ISO is missing the {repo} file-list database (.files). "
                "Rebuild it with build.sh to create complete package caches."
            )


def install_system(packages: list[str], profile: str, hw: Hardware, offline: bool) -> None:
    """Install the full system from network repos or the ISO's frozen snapshot."""
    step("Installing the system from the ISO snapshot" if offline else
         "Installing the system packages from the network")
    kernel_packages = ["linux-cachyos", "linux-cachyos-lts", "linux-firmware"]
    kernel_packages += [p for p in hw.extra_packages if p in KERNEL_CACHE_PACKAGES]
    targets = list(dict.fromkeys(kernel_packages + packages))
    if offline:
        config = _offline_pacman_config(profile)
        run(["pacstrap", "-C", str(config), "-P", MOUNT, *targets])
    else:
        run(["pacstrap", "-C", "/etc/pacman.conf", "-P", MOUNT, *targets])
