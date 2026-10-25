"""Limine bootloader (UEFI only).

limine-mkinitcpio-hook / limine-snapper-sync own the boot entries and the
"Snapshots" menu inside /boot/limine.conf. This module writes only the global
options plus an OS header, rebuilds the initramfs, lets the tool generate the
entries, and falls back to one hand-written entry if it produced none.
"""
from __future__ import annotations

from pathlib import Path

from config import (
    KERNEL_CMDLINE,
    LIMINE_BASE_CONF,
    LIMINE_DEFAULT,
    MOUNT,
)
from disk import Layout
from shell import chroot, put, run
from ui import console, step


def install_bootloader(disk: str, layout: Layout) -> None:
    step("Bootloader (Limine)")
    cmdline = KERNEL_CMDLINE.format(root_uuid=layout.root_uuid, swap_uuid=layout.swap_uuid)

    put("/etc/default/limine", LIMINE_DEFAULT.format(cmdline=cmdline))

    boot = Path(MOUNT) / "boot"
    (boot / "EFI/BOOT").mkdir(parents=True, exist_ok=True)
    # Single config location: the one limine-snapper-sync edits. A second copy
    # in /boot/limine/ would go stale and might be picked up instead.
    put("/boot/limine.conf", LIMINE_BASE_CONF)
    run(["cp", "/usr/share/limine/BOOTX64.EFI", str(boot / "EFI/BOOT/BOOTX64.EFI")])

    # Rebuild initramfs now that the resume hook is in place.
    chroot("mkinitcpio", "-P")
    # Generate kernel entries from /etc/default/limine.
    chroot("limine-update", check=False)

    conf = (boot / "limine.conf").read_text()
    if "vmlinuz" not in conf:
        console.print(
            "[yellow]limine-update produced no boot entry; writing a manual one. "
            "Snapshot entries will be added by limine-snapper-sync.[/]"
        )
        with open(boot / "limine.conf", "a") as f:
            f.write(
                "\n/Veyra OS (manual)\n"
                "    protocol: linux\n"
                "    kernel_path: boot():/vmlinuz-linux-cachyos\n"
                "    module_path: boot():/initramfs-linux-cachyos.img\n"
                f"    cmdline: {cmdline}\n"
            )

    chroot(
        "efibootmgr", "--create", "--disk", disk, "--part", "1",
        "--label", "Veyra OS (Limine)", "--loader", "\\EFI\\BOOT\\BOOTX64.EFI",
        check=False,
    )