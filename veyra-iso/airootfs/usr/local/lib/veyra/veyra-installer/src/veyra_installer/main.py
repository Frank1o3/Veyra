#!/usr/bin/env python3
"""Veyra OS guided installer: entry point.

Run from the project directory with `uv run main.py`, or on the ISO with
`python3 /usr/local/lib/veyra/installer/main.py`.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from rich.panel import Panel
from rich.prompt import Prompt
from rich.table import Table

from . import bootloader
from . import disk
from . import memory
from . import network
from . import packages
from . import postinstall
from . import snapshots
from . import system
from .config import DEFAULT_HOSTNAME, KERNEL_PROFILES, LOG_FILE, MOUNT
from .hardware import detect_hardware, swap_size_mib
from .shell import InstallerError, is_mounted, run
from .ui import (
    ask_keyboard,
    ask_locale,
    ask_password,
    ask_timezone,
    ask_kernel_profile,
    ask_package_sources,
    ask_validated,
    banner,
    console,
    step,
)


def main() -> int:
    if os.geteuid() != 0:
        console.print("[red]Run this installer as root.[/]")
        return 1
    if is_mounted(MOUNT):
        console.print(f"[red]{MOUNT} is already mounted; unmount it first.[/]")
        return 1
    if not Path("/sys/firmware/efi").is_dir():
        console.print("[red]Veyra requires UEFI firmware; boot the ISO in UEFI mode.[/]")
        return 1

    layout: disk.Layout | None = None
    mounted = False
    try:
        banner()

        step("Network")
        online = network.ensure_network()

        hw = detect_hardware()
        console.print(
            f"CPU: [bold]{hw.cpu_vendor}[/]   GPUs: [bold]"
            f"{', '.join(hw.gpu_vendors) or 'none'}[/]   "
            f"x86-64-v3: [bold]{'yes' if hw.v3 else 'no'}[/]"
            f"   x86-64-v4: [bold]{'yes' if hw.v4 else 'no'}[/]"
        )
        if hw.nvidia_open:
            console.print(f"NVIDIA {hw.nvidia_model}: using the open NVIDIA driver.")
        elif hw.nvidia_proprietary:
            console.print(f"NVIDIA {hw.nvidia_model}: using the proprietary 580 driver.")
        elif "nvidia" in hw.gpu_vendors:
            console.print(
                "[yellow]NVIDIA model could not be identified; keeping Nouveau enabled. "
                "Install a suitable driver after setup.[/]"
            )

        step("Setup questions")
        target_disk = disk.pick_disk()
        swap_mib = swap_size_mib()
        disk.check_capacity(target_disk, swap_mib)

        username = ask_validated(
            "Username", r"[a-z_][a-z0-9_-]*\$?", "Use a lowercase Linux username."
        )
        hostname = ask_validated(
            "Hostname", r"[a-zA-Z0-9][a-zA-Z0-9-]{0,62}", "Invalid hostname.", DEFAULT_HOSTNAME
        )
        locale = ask_locale()
        timezone = ask_timezone()
        xkb_layout, console_keymap = ask_keyboard()
        password = ask_password()
        kernel_profile = ask_kernel_profile(hw)
        kernel_source, package_source = ask_package_sources(online)

        pkgs = packages.build_package_list(hw, kernel_profile)
        packages.prepare_keys_and_mirrors(
            hw,
            kernel_profile,
            online=online,
            sync_databases=(kernel_source == "network" or package_source == "network"),
        )
        packages.validate_offline_cache(
            kernel_profile,
            kernel=kernel_source == "cache",
            packages=package_source == "cache",
        )

        summary = Table(title="Summary", show_header=False)
        for k, v in (
            ("Disk", target_disk),
            ("Layout", f"ESP 1 GiB + swap {swap_mib // 1024} GiB (hibernation) + btrfs root"),
            ("User", username),
            ("Hostname", hostname),
            ("Locale", locale),
            ("Timezone", timezone),
            ("Keyboard", f"{xkb_layout} (console: {console_keymap})"),
            ("Kernel", KERNEL_PROFILES[kernel_profile][0]),
            ("Kernel and drivers", kernel_source),
            ("System packages", package_source),
            ("Packages", str(len(pkgs))),
        ):
            summary.add_row(k, v)
        console.print(summary)
        console.print(Panel(f"[bold red]{target_disk} will be completely erased.[/]", border_style="red"))
        if Prompt.ask("Type ERASE to continue") != "ERASE":
            console.print("Confirmation did not match; no disk changes made.")
            return 1

        mounted = True
        layout = disk.partition_and_mount(target_disk, swap_mib)

        packages.install_system(
            pkgs, kernel_profile, hw, kernel_source, package_source
        )

        cfg = dict(
            username=username,
            hostname=hostname,
            locale=locale,
            timezone=timezone,
            xkb_layout=xkb_layout,
            console_keymap=console_keymap,
            password=password,
        )
        system.configure_system(cfg)
        memory.configure_zram()
        memory.configure_hibernation()
        snapshots.configure_snapshots()
        snapshots.configure_cleanup()
        system.install_dotfiles(cfg)
        postinstall.install_rivet(cfg)
        postinstall.install_firstboot(cfg)
        system.enable_services()
        bootloader.install_bootloader(target_disk, layout)
        snapshots.create_initial_snapshot()

        run(["swapoff", layout.swap], check=False)
        run(["umount", "-R", MOUNT])
        mounted = False
        console.print(
            Panel("[bold green]Veyra is installed.[/] Remove the ISO and reboot.", border_style="green")
        )
        Prompt.ask("Press Enter to return to the live system", default="")
        return 0

    except InstallerError as exc:
        console.print(f"\n[bold red]Installer stopped:[/] {exc}")
        console.print(f"See {LOG_FILE} for details.")
        return 1
    except KeyboardInterrupt:
        console.print("\n[yellow]Cancelled.[/]")
        return 130
    finally:
        if mounted and is_mounted(MOUNT):
            if layout:
                subprocess.run(["swapoff", layout.swap])
            subprocess.run(["umount", "-R", MOUNT])


if __name__ == "__main__":
    sys.exit(main())
