"""Disk selection, partitioning, btrfs subvolumes and mounting.

Layout (UEFI only):
    1  ESP        FAT32, mounted at /boot (Limine + kernels + snapshot entries)
    2  swap       sized to RAM so hibernation (resume=) always fits
    3  root       btrfs, subvolumes from config.SUBVOLUMES

No @snapshots subvolume on purpose: snapper creates a nested .snapshots inside
@, which is what limine-snapper-sync expects.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from rich.prompt import Prompt
from rich.table import Table

from .config import BTRFS_OPTS, ESP_SIZE_MIB, MIN_ROOT_GIB, MOUNT, SUBVOLUMES
from .shell import InstallerError, capture, run
from .ui import console, step


@dataclass
class Layout:
    esp: str
    swap: str
    root: str
    root_uuid: str = ""
    swap_uuid: str = ""


def pick_disk() -> str:
    data = json.loads(capture("lsblk -dpJo NAME,SIZE,MODEL,TYPE"))
    tree = json.loads(capture("lsblk -pJo NAME,TYPE,MOUNTPOINTS"))

    def in_use(node) -> bool:
        if any(m for m in (node.get("mountpoints") or []) if m):
            return True
        return any(in_use(c) for c in node.get("children", []))

    busy = {n["name"] for n in tree.get("blockdevices", []) if in_use(n)}
    disks = [d for d in data.get("blockdevices", []) if d["type"] == "disk"]
    if not disks:
        raise InstallerError("no install disks were found")

    table = Table(title="Install target disks")
    for col in ("#", "Device", "Size", "Model", "Note"):
        table.add_column(col, justify="right" if col in ("#", "Size") else "left")
    for i, d in enumerate(disks, 1):
        table.add_row(
            str(i),
            d["name"],
            d["size"],
            (d.get("model") or "").strip(),
            "[red]has mounted partitions[/]" if d["name"] in busy else "",
        )
    console.print(table)

    while True:
        choice = Prompt.ask("Choose a disk number")
        if choice.isdigit() and 1 <= int(choice) <= len(disks):
            disk = disks[int(choice) - 1]["name"]
            if disk in busy:
                console.print(
                    "[red]That disk has mounted partitions (possibly the install "
                    "media). Unmount them or pick another disk.[/]"
                )
                continue
            return disk
        console.print("[red]Invalid selection.[/]")


def check_capacity(disk: str, swap_mib: int) -> None:
    out = capture(["lsblk", "-bdno", "SIZE", disk]).strip()
    size_mib = int(out) // (1024 * 1024) if out.isdigit() else 0
    needed = ESP_SIZE_MIB + swap_mib + MIN_ROOT_GIB * 1024
    if size_mib < needed:
        raise InstallerError(
            f"{disk} is too small: need at least {needed // 1024} GiB "
            f"(ESP {ESP_SIZE_MIB} MiB + swap {swap_mib // 1024} GiB + {MIN_ROOT_GIB} GiB root)"
        )


def _part(disk: str, n: int) -> str:
    sep = "p" if Path(disk).name.startswith(("nvme", "mmcblk")) else ""
    return f"{disk}{sep}{n}"


def partition_and_mount(disk: str, swap_mib: int) -> Layout:
    step("Partitioning")
    layout = Layout(esp=_part(disk, 1), swap=_part(disk, 2), root=_part(disk, 3))

    run(["sgdisk", "--zap-all", disk])
    run(["sgdisk", f"--new=1:0:+{ESP_SIZE_MIB}MiB", "--typecode=1:ef00", "--change-name=1:VeyraEFI", disk])
    run(["sgdisk", f"--new=2:0:+{swap_mib}MiB", "--typecode=2:8200", "--change-name=2:VeyraSwap", disk])
    run(["sgdisk", "--new=3:0:0", "--typecode=3:8300", "--change-name=3:VeyraRoot", disk])
    run(["blockdev", "--rereadpt", disk], check=False)
    run("udevadm settle")

    run(["mkfs.fat", "-F32", "-n", "VEYRA_EFI", layout.esp])
    run(["mkswap", "-L", "VEYRA_SWAP", layout.swap])
    run(["mkfs.btrfs", "-f", "-L", "VEYRA_ROOT", layout.root])

    Path(MOUNT).mkdir(exist_ok=True)
    run(["mount", layout.root, MOUNT])
    for name, _ in SUBVOLUMES:
        run(["btrfs", "subvolume", "create", f"{MOUNT}/{name}"])
    run(["umount", MOUNT])

    # Root subvolume first, then everything nested under it.
    for name, mountpoint in SUBVOLUMES:
        dest = MOUNT if mountpoint == "/" else f"{MOUNT}{mountpoint}"
        Path(dest).mkdir(parents=True, exist_ok=True)
        run(["mount", "-o", f"{BTRFS_OPTS},subvol={name}", layout.root, dest])
    Path(f"{MOUNT}/boot").mkdir(exist_ok=True)
    run(["mount", layout.esp, f"{MOUNT}/boot"])

    # Active swap lets genfstab record it in /etc/fstab.
    run(["swapon", layout.swap])

    layout.root_uuid = capture(["blkid", "-s", "UUID", "-o", "value", layout.root]).strip()
    layout.swap_uuid = capture(["blkid", "-s", "UUID", "-o", "value", layout.swap]).strip()
    if not layout.root_uuid or not layout.swap_uuid:
        raise InstallerError("could not read partition UUIDs")
    return layout