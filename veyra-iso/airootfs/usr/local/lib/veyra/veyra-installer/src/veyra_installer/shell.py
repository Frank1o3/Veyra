"""Process helpers and helpers for writing into the target filesystem."""
from __future__ import annotations

import shlex
import subprocess
from pathlib import Path

from .config import LOG_FILE, MOUNT


class InstallerError(Exception):
    """Fatal installer problem: shown to the user, then the install aborts."""


def run(cmd, *, check: bool = True, input_text: str | None = None, log: bool = True) -> int:
    """Run a command.

    Logged commands go through `script` so they keep a real TTY (pacman
    progress bars work) while still being appended to LOG_FILE. Commands that
    receive input_text (passwords) are never logged.
    """
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    if input_text is not None or not log:
        result = subprocess.run(cmd, input=input_text, text=True)
    else:
        result = subprocess.run(["script", "-qefa", "-c", shlex.join(cmd), LOG_FILE])
    if check and result.returncode != 0:
        raise InstallerError(f"command failed ({result.returncode}): {shlex.join(cmd)}")
    return result.returncode


def capture(cmd) -> str:
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    try:
        return subprocess.run(cmd, capture_output=True, text=True).stdout
    except FileNotFoundError:
        return ""


def chroot(*cmd: str, check: bool = True, input_text: str | None = None) -> int:
    return run(["arch-chroot", MOUNT, *cmd], check=check, input_text=input_text)


def is_mounted(path: str) -> bool:
    return subprocess.run(["mountpoint", "-q", path]).returncode == 0


def target(path: str) -> Path:
    """Map an absolute path inside the new system to its location under MOUNT."""
    return Path(MOUNT) / path.lstrip("/")


def put(path: str, text: str, mode: int = 0o644) -> None:
    """Write a file into the new system, creating parent directories."""
    dest = target(path)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text)
    dest.chmod(mode)