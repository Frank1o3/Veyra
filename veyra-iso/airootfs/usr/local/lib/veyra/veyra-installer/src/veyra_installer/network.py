"""Network connectivity check for the live environment."""
from __future__ import annotations

import subprocess
import time

from rich.prompt import Prompt

from .shell import InstallerError, run
from .ui import console


def have_network() -> bool:
    if subprocess.run(["ping", "-c1", "-W3", "archlinux.org"], capture_output=True).returncode == 0:
        return True
    return (
        subprocess.run(
            ["curl", "-fsI", "--max-time", "5", "https://archlinux.org"], capture_output=True
        ).returncode
        == 0
    )


def ensure_network() -> None:
    run("systemctl start NetworkManager.service", check=False, log=False)
    run("rfkill unblock wifi", check=False, log=False)
    time.sleep(2)
    while not have_network():
        console.print("\n[yellow]No internet connection detected.[/]")
        choice = Prompt.ask(
            "  [1] open network setup (nmtui)  [2] retry  [3] quit",
            choices=["1", "2", "3"],
            default="1",
        )
        if choice == "1":
            run("nmtui", check=False, log=False)
            time.sleep(3)
        elif choice == "3":
            raise InstallerError("no network connection")
    console.print("[green]Network connection OK.[/]")