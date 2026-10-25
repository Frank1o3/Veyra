"""Base system configuration inside the chroot: fstab, locale, users, dotfiles, services."""
from __future__ import annotations

import re
import shlex

from .config import (
    DOTFILES_URL,
    MOUNT,
    SERVICES_ENABLE,
    SERVICES_GLOBAL,
    SWAP_PRIORITY,
)
from .shell import capture, chroot, put, run, target
from .ui import step


def configure_system(cfg: dict) -> None:
    step("System configuration")
    chroot("pacman-key", "--populate", "archlinux", "cachyos")

    fstab = capture(["genfstab", "-U", MOUNT])
    # Pinned subvolids break snapshot restore (the "replace" method creates a
    # new subvolume with a new id), so keep only subvol=.
    fstab = re.sub(r",subvolid=\d+", "", fstab)
    # Disk swap must rank below zram.
    fstab = re.sub(r"(\sswap\s+)defaults", rf"\1defaults,pri={SWAP_PRIORITY}", fstab)
    put("/etc/fstab", fstab)

    run(["install", "-Dm644", "/etc/pacman.conf", f"{MOUNT}/etc/pacman.conf"])
    run(["install", "-Dm644", "/etc/pacman.d/cachyos-mirrorlist",
         f"{MOUNT}/etc/pacman.d/cachyos-mirrorlist"])
    put("/etc/hostname", cfg["hostname"] + "\n")

    locale_gen = target("/etc/locale.gen")
    wanted = f"{cfg['locale']} UTF-8"
    locale_gen.write_text(
        "\n".join(
            line[1:] if line == f"#{wanted}" else line
            for line in locale_gen.read_text().splitlines()
        )
        + "\n"
    )
    put("/etc/locale.conf", f"LANG={cfg['locale']}\n")
    put("/etc/vconsole.conf", f"KEYMAP={cfg['console_keymap']}\n")
    put(
        "/etc/X11/xorg.conf.d/00-keyboard.conf",
        'Section "InputClass"\n'
        '    Identifier "system-keyboard"\n'
        '    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{cfg["xkb_layout"]}"\n'
        "EndSection\n",
    )

    tz = target("/etc/localtime")
    tz.unlink(missing_ok=True)
    tz.symlink_to(f"/usr/share/zoneinfo/{cfg['timezone']}")

    chroot("locale-gen")
    chroot("useradd", "-m", "-G", "wheel", "-s", "/usr/bin/fish", cfg["username"])
    chroot("chpasswd", input_text=f"{cfg['username']}:{cfg['password']}\n")
    put("/etc/sudoers.d/10-wheel", "%wheel ALL=(ALL:ALL) ALL\n", 0o440)


def install_dotfiles(cfg: dict) -> None:
    step("Desktop configuration")
    user = shlex.quote(cfg["username"])
    chroot(
        "bash", "-c",
        f"git clone --depth 1 {DOTFILES_URL} /tmp/dotfiles && "
        f"/tmp/dotfiles/setup.sh --config-only --user {user}; "
        "rm -rf /tmp/dotfiles",
    )

    # The dotfiles hardcode kb_layout = "us"; apply the chosen layout.
    # input.lua is seed-only in sync-config.py, so updates won't undo this.
    input_lua = target(f"/home/{cfg['username']}/.config/hypr/modules/input.lua")
    if input_lua.exists():
        text = input_lua.read_text()
        input_lua.write_text(
            re.sub(r'kb_layout\s*=\s*"[^"]*"', f'kb_layout = "{cfg["xkb_layout"]}"', text)
        )


def enable_services() -> None:
    step("Services")
    chroot("systemctl", "enable", *SERVICES_ENABLE, check=False)
    chroot("systemctl", "--global", "enable", *SERVICES_GLOBAL, check=False)
    chroot("systemctl", "set-default", "graphical.target")