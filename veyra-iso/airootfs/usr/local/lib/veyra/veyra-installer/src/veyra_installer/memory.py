"""zram swap plus disk-swap hibernation support.

The disk swap partition is recorded in fstab by genfstab (low priority); zram
gets a higher priority so it is used first. Hibernation does not care about
priority: the kernel writes the image to the device named by resume=.
"""
from __future__ import annotations

import re

from .config import ZRAM_CONF, ZRAM_SYSCTL
from .shell import InstallerError, put, target
from .ui import step


def configure_zram() -> None:
    step("zram")
    put("/etc/systemd/zram-generator.conf", ZRAM_CONF)
    put("/etc/sysctl.d/99-veyra-zram.conf", ZRAM_SYSCTL)


def configure_hibernation() -> None:
    """Add the `resume` hook to mkinitcpio (after udev, before filesystems).

    The initramfs is rebuilt later by the bootloader step. The resume=
    kernel parameter itself lives in config.KERNEL_CMDLINE.
    """
    step("Hibernation")
    conf = target("/etc/mkinitcpio.conf")
    text = conf.read_text()

    match = re.search(r"^HOOKS=\((.*?)\)", text, re.MULTILINE)
    if not match:
        raise InstallerError("could not find HOOKS=(...) in /etc/mkinitcpio.conf")

    hooks = match.group(1).split()
    if "resume" not in hooks:
        if "filesystems" in hooks:
            hooks.insert(hooks.index("filesystems"), "resume")
        else:
            hooks.append("resume")
        text = text.replace(match.group(0), f"HOOKS=({' '.join(hooks)})", 1)
        conf.write_text(text)