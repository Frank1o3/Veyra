"""Package selection, keyring/mirror preparation and pacstrap."""
from __future__ import annotations

from pathlib import Path

from .config import BASE_PACKAGES, MOUNT
from .hardware import Hardware
from .shell import run
from .ui import console, step


def build_package_list(hw: Hardware, use_v3_kernel: bool) -> list[str]:
    packages = list(dict.fromkeys(BASE_PACKAGES + hw.extra_packages))
    if not use_v3_kernel:
        # Force the generic kernel from the standard CachyOS repo.
        packages = [("cachyos/" + p) if p.startswith("linux-cachyos") else p for p in packages]
    return packages


def prepare_keys_and_mirrors(hw: Hardware) -> None:
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

    if hw.v3:
        console.print("CPU supports x86-64-v3; using the CachyOS v3 mirrorlist.")
        conf = Path("/etc/pacman.conf")
        conf.write_text(
            conf.read_text().replace(
                "/etc/pacman.d/cachyos-mirrorlist", "/etc/pacman.d/cachyos-v3-mirrorlist"
            )
        )
    else:
        console.print("CPU does not support x86-64-v3; using standard CachyOS packages.")
    run("pacman -Syy --noconfirm")


def install_base(packages: list[str]) -> None:
    step("Installing packages (this takes a while)")
    run(["pacstrap", MOUNT, *packages])