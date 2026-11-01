"""Package selection, keyring/mirror preparation and pacstrap."""
from __future__ import annotations

from pathlib import Path

from .config import BASE_PACKAGES, KERNEL_PROFILES, MOUNT
from .hardware import Hardware
from .shell import InstallerError, run
from .ui import console, step


KERNEL_CACHE_PACKAGES = {
    "linux-firmware", "intel-ucode", "amd-ucode", "mesa", "vulkan-intel",
    "intel-media-driver", "vulkan-radeon", "dkms",
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


def prepare_keys_and_mirrors(
    hw: Hardware, profile: str, online: bool, sync_databases: bool
) -> None:
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
    if online:
        mirrorlists = [
            Path("/etc/pacman.d/mirrorlist"),
            Path("/etc/pacman.d/cachyos-mirrorlist"),
            Path("/etc/pacman.d/cachyos-v3-mirrorlist"),
            Path("/etc/pacman.d/cachyos-v4-mirrorlist"),
        ]
        backups = {path: path.read_bytes() for path in mirrorlists if path.is_file()}
        console.print("Ranking Arch mirrors (this can take a minute)...")
        rc = run(["cachyos-rate-mirrors"], check=False)
        if rc != 0:
            console.print("[yellow]Mirror ranking failed; keeping the default mirrorlist.[/]")
            for path, contents in backups.items():
                path.write_bytes(contents)
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
    if not sync_databases:
        console.print("Using package databases and archives from the ISO snapshot.")
    else:
        run("pacman -Syy --noconfirm")


def _cache_repo_name(profile: str) -> str:
    return {"generic": "veyra-kernel", "v3": "veyra-kernel-v3",
            "v4": "veyra-kernel-v4", "znver4": "veyra-kernel-znver4"}[profile]


def _package_cache_repo_name(profile: str) -> str:
    return f"veyra-packages-{profile}"


def cached_package_archives(cache: Path) -> list[Path]:
    """Return cached package archives in stable order for inspection/tools."""
    return sorted(cache.glob("*.pkg.tar.zst"))


def _install_pacman_config(
    profile: str, kernel_source: str, package_source: str
) -> Path:
    use_kernel_cache = kernel_source == "cache"
    use_package_cache = package_source == "cache"
    validate_offline_cache(
        profile, kernel=use_kernel_cache, packages=use_package_cache
    )
    root = Path("/usr/share/veyra")
    local_repos = ""
    if use_kernel_cache:
        kernel_repo = root / "kernel-cache" / profile
        local_repos += (
            f"[{_cache_repo_name(profile)}]\n"
            f"Server = file://{kernel_repo}\n\n"
        )
    if use_package_cache:
        package_repo = root / "package-cache" / profile
        local_repos += (
            f"[{_package_cache_repo_name(profile)}]\n"
            f"Server = file://{package_repo}\n\n"
        )
    config = Path("/tmp/veyra-install-pacman.conf")
    if kernel_source == "network" or package_source == "network":
        base_config = Path("/etc/pacman.conf").read_text()
        first_repo = base_config.find("[cachyos]")
        if first_repo < 0:
            raise InstallerError("The live ISO pacman.conf has no [cachyos] repository.")
        config.write_text(base_config[:first_repo] + local_repos + base_config[first_repo:])
    else:
        config.write_text(
            "[options]\nArchitecture = auto\nSigLevel = Required DatabaseOptional\n"
            "LocalFileSigLevel = Optional\n\n" + local_repos
        )
    return config


def validate_offline_cache(
    profile: str, *, kernel: bool = True, packages: bool = True
) -> None:
    if profile not in KERNEL_PROFILES:
        raise InstallerError(f"Unknown CachyOS package profile: {profile}")
    root = Path("/usr/share/veyra")
    kernel_repo = root / "kernel-cache" / profile
    package_repo = root / "package-cache" / profile
    kernel_name = _cache_repo_name(profile)
    package_name = _package_cache_repo_name(profile)
    required_repos = []
    if kernel:
        required_repos.append((kernel_repo, kernel_name))
    if packages:
        required_repos.append((package_repo, package_name))
    for directory, repo in required_repos:
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


def install_system(
    packages: list[str], profile: str, hw: Hardware,
    kernel_source: str, package_source: str,
) -> None:
    """Install kernel/driver and system packages from their chosen sources."""
    step("Installing the system")
    kernel_packages = ["linux-cachyos", "linux-cachyos-lts", "linux-firmware"]
    kernel_packages += [p for p in hw.extra_packages if p in KERNEL_CACHE_PACKAGES]
    kernel_targets = list(dict.fromkeys(kernel_packages))
    package_targets = list(dict.fromkeys(packages))
    config = _install_pacman_config(profile, kernel_source, package_source)
    run([
        "pacstrap", "-C", str(config), "-P", MOUNT,
        *(kernel_targets + package_targets),
    ])
