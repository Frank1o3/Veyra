"""Snapper configuration and automatic disk cleanup/sanitization."""
from __future__ import annotations

from .config import CLEANUP_FILES, SNAPPER_CONF
from .shell import chroot, put
from .ui import step


def configure_snapshots() -> None:
    step("Snapshots")
    # --no-dbus: there is no system bus inside the chroot. create-config needs
    # /.snapshots to NOT exist, so it must not be a separate mounted subvolume.
    chroot("snapper", "--no-dbus", "-c", "root", "create-config", "/")
    put("/etc/snapper/configs/root", SNAPPER_CONF, 0o640)
    chroot("chmod", "750", "/.snapshots")


def configure_cleanup() -> None:
    step("Automatic cleanup")
    for path, content in CLEANUP_FILES.items():
        put(path, content)

def create_initial_snapshot() -> None:
    step("Initial snapshot")
    chroot("snapper", "--no-dbus", "-c", "root", "create",
           "--cleanup-algorithm", "number", "-d", "Fresh install", check=False)