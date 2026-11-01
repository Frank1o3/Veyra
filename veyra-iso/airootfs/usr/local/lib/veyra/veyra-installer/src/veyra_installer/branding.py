"""Veyra identity for the installed system and Fastfetch."""
from __future__ import annotations

import re

from .shell import target


FASTFETCH_CONFIG = r'''{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "data-raw",
    "source": "    __      __\n   / /___  / /____  ____ _\n  / / __ \\/ __/ _ \\/ __ `/\n / / /_/ / /_/  __/ /_/ /\n/_/\\____/\\__/\\___/\\__,_/\n\n     V E Y R A   O S"
  }
}
'''


def set_os_release_identity() -> None:
    """Keep Arch compatibility while identifying the installed distribution."""
    path = target("/usr/lib/os-release")
    content = path.read_text()
    values = {
        "NAME": '"Veyra OS"',
        "PRETTY_NAME": '"Veyra OS"',
        "ID": "veyra",
        "ID_LIKE": "arch",
        "LOGO": "veyra",
        "ANSI_COLOR": '"38;2;123;174;242"',
    }
    for key, value in values.items():
        line = f"{key}={value}"
        pattern = rf"(?m)^{re.escape(key)}=.*$"
        if re.search(pattern, content):
            content = re.sub(pattern, lambda _: line, content)
        else:
            content += f"\n{line}"
    path.write_text(content.rstrip() + "\n")


def install_fastfetch_config(username: str) -> None:
    config = target(f"/home/{username}/.config/fastfetch/config.jsonc")
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(FASTFETCH_CONFIG)
