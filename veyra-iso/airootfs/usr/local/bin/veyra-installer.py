#!/usr/bin/env python3
"""Veyra OS guided installer (replaces veyra-installer.sh + hardware.sh)."""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.prompt import Confirm, Prompt
    from rich.table import Table
except ImportError:
    sys.exit("python-rich is missing from the live image (add it to packages.x86_64).")

console = Console()

LOG_FILE = "/tmp/veyra-install.log"
MOUNT = "/mnt"
DOTFILES_URL = "https://github.com/Frank1o3/dotfiles.git"
BTRFS_OPTS = "noatime,compress=zstd:3,space_cache=v2"

BASE_PACKAGES = [
    "base", "linux-cachyos", "linux-firmware", "cachyos-keyring", "cachyos-mirrorlist",
    "btrfs-progs", "networkmanager", "sudo", "git", "nano", "fish", "cachyos-fish-config",
    "hyprland", "hyprlock", "hypridle", "hyprshutdown", "hyprpolkitagent", "quickshell", "sddm",
    "kitty", "awww",
    "pipewire", "pipewire-pulse", "wireplumber",
    "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk",
    "gnome-keyring", "nm-connection-editor", "network-manager-applet",
    "brightnessctl", "playerctl", "thunar", "gvfs", "tumbler", "file-roller",
    "adw-gtk-theme", "papirus-icon-theme", "adwaita-cursors",
    "ttf-jetbrains-mono-nerd", "ttf-nerd-fonts-symbols", "ttf-nerd-fonts-symbols-common",
    "qt6ct", "qt6-5compat", "python", "rsync",
    "limine", "limine-mkinitcpio-hook", "limine-snapper-sync", "snapper", "efibootmgr",
    "cava", "inter-font", "qt5-graphicaleffects", "qt5-quickcontrols2"
]

# XKB layout name (what Hyprland/SDDM use) -> console keymap name (what vconsole uses).
# They are NOT the same namespace: e.g. XKB "latam" is console "la-latin1".
XKB_TO_CONSOLE = {
    "us": "us", "latam": "la-latin1", "es": "es", "gb": "uk", "de": "de-latin1",
    "fr": "fr", "it": "it", "pt": "pt-latin1", "br": "br-abnt2", "ru": "ru",
    "se": "sv-latin1", "no": "no-latin1", "dk": "dk-latin1", "fi": "fi",
    "pl": "pl2", "cz": "cz-lat2", "tr": "trq", "jp": "jp106", "ca": "cf",
}

V3_FLAGS = (
    "avx", "avx2", "bmi1", "bmi2", "f16c", "fma", "abm", "movbe", "xsave",
    "cx16", "lahf_lm", "popcnt", "pni", "ssse3", "sse4_1", "sse4_2",
)


class InstallerError(Exception):
    pass


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def run(cmd, *, check=True, input_text=None, log=True) -> int:
    """Run a command. Logged commands go through `script` so they keep a real
    TTY (pacman progress bars work) while still being appended to LOG_FILE."""
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


def chroot(*cmd, check=True, input_text=None) -> int:
    return run(["arch-chroot", MOUNT, *cmd], check=check, input_text=input_text)


def is_mounted(path: str) -> bool:
    return subprocess.run(["mountpoint", "-q", path]).returncode == 0


def step(title: str) -> None:
    console.print()
    console.rule(f"[bold cyan]{title}")


# --------------------------------------------------------------------------
# hardware detection (port of hardware.sh)
# --------------------------------------------------------------------------
@dataclass
class Hardware:
    cpu_vendor: str = "other"
    gpu_vendors: list[str] = field(default_factory=list)
    extra_packages: list[str] = field(default_factory=list)
    nvidia_open: bool = False
    v3: bool = False


def cpu_flags() -> set[str]:
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("flags"):
            return set(line.split(":", 1)[1].split())
    return set()


def supports_v3() -> bool:
    # Preferred: ask glibc's loader. Fallback: check flags with the names
    # /proc/cpuinfo really uses (abm = lzcnt, pni = sse3).
    for loader in ("/lib64/ld-linux-x86-64.so.2", "/lib/ld-linux-x86-64.so.2"):
        if Path(loader).exists():
            out = capture([loader, "--help"])
            if out:
                return "x86-64-v3 (supported, searched)" in out
    return set(V3_FLAGS) <= cpu_flags()


def detect_hardware() -> Hardware:
    hw = Hardware(v3=supports_v3())

    cpuinfo = Path("/proc/cpuinfo").read_text()
    if "GenuineIntel" in cpuinfo:
        hw.cpu_vendor = "intel"
        hw.extra_packages.append("intel-ucode")
    elif "AuthenticAMD" in cpuinfo:
        hw.cpu_vendor = "amd"
        hw.extra_packages.append("amd-ucode")

    for dev in sorted(Path("/sys/bus/pci/devices").glob("*")):
        try:
            if not (dev / "class").read_text().strip().startswith("0x03"):
                continue
            vendor = (dev / "vendor").read_text().strip()
            device_id = (dev / "device").read_text().strip()
        except OSError:
            continue
        if vendor == "0x8086":
            gpu = "intel"
        elif vendor == "0x1002":
            gpu = "amd"
        elif vendor == "0x10de":
            gpu = "nvidia"
            # Open kernel modules need Turing (device IDs 0x1e00+).
            try:
                if int(device_id, 16) >= 0x1E00:
                    hw.nvidia_open = True
            except ValueError:
                pass
        else:
            gpu = "other"
        if gpu not in hw.gpu_vendors:
            hw.gpu_vendors.append(gpu)

    if "intel" in hw.gpu_vendors:
        hw.extra_packages += ["mesa", "vulkan-intel", "intel-media-driver"]
    if "amd" in hw.gpu_vendors:
        hw.extra_packages += ["mesa", "vulkan-radeon", "libva-mesa-driver"]
    if hw.nvidia_open:
        hw.extra_packages += [
            "dkms", "linux-cachyos-headers", "nvidia-open-dkms",
            "nvidia-utils", "lib32-nvidia-utils", "vulkan-icd-loader",
        ]
    # de-duplicate, keep order
    hw.extra_packages = list(dict.fromkeys(hw.extra_packages))
    return hw


# --------------------------------------------------------------------------
# network
# --------------------------------------------------------------------------
def have_network() -> bool:
    if subprocess.run(["ping", "-c1", "-W3", "archlinux.org"],
                      capture_output=True).returncode == 0:
        return True
    return subprocess.run(["curl", "-fsI", "--max-time", "5", "https://archlinux.org"],
                          capture_output=True).returncode == 0


def ensure_network() -> None:
    run("systemctl start NetworkManager.service", check=False, log=False)
    run("rfkill unblock wifi", check=False, log=False)
    time.sleep(2)
    while not have_network():
        console.print("\n[yellow]No internet connection detected.[/]")
        choice = Prompt.ask("  [1] open network setup (nmtui)  [2] retry  [3] quit",
                            choices=["1", "2", "3"], default="1")
        if choice == "1":
            run("nmtui", check=False, log=False)
            time.sleep(3)
        elif choice == "3":
            raise InstallerError("no network connection")
    console.print("[green]Network connection OK.[/]")


# --------------------------------------------------------------------------
# prompts
# --------------------------------------------------------------------------
def console_keymaps() -> set[str]:
    names = set()
    for p in Path("/usr/share/kbd/keymaps").rglob("*.map*"):
        names.add(p.name.split(".map")[0])
    return names


def ask_keyboard() -> tuple[str, str]:
    """Returns (xkb_layout, console_keymap)."""
    maps = console_keymaps()
    while True:
        layout = Prompt.ask(
            "Keyboard layout [dim](us, latam, es, gb, de, fr, br, ...)[/]", default="us"
        ).strip().lower()
        if layout in XKB_TO_CONSOLE:
            xkb, cmap = layout, XKB_TO_CONSOLE[layout]
        elif layout in maps:
            xkb, cmap = layout, layout
            console.print(f"[yellow]Using '{layout}' for both console and desktop; "
                          "adjust the desktop layout later if it differs.[/]")
        else:
            console.print(f"[red]Unknown layout '{layout}'.[/]")
            continue
        if maps and cmap not in maps:
            console.print(f"[red]Console keymap '{cmap}' is not available in this image.[/]")
            continue
        return xkb, cmap


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
    table.add_column("#", justify="right")
    table.add_column("Device")
    table.add_column("Size", justify="right")
    table.add_column("Model")
    table.add_column("Note")
    for i, d in enumerate(disks, 1):
        table.add_row(str(i), d["name"], d["size"], (d.get("model") or "").strip(),
                      "[red]has mounted partitions[/]" if d["name"] in busy else "")
    console.print(table)

    while True:
        choice = Prompt.ask("Choose a disk number")
        if choice.isdigit() and 1 <= int(choice) <= len(disks):
            disk = disks[int(choice) - 1]["name"]
            if disk in busy:
                console.print("[red]That disk has mounted partitions (possibly the install "
                              "media). Unmount them or pick another disk.[/]")
                continue
            return disk
        console.print("[red]Invalid selection.[/]")


def ask_validated(prompt: str, pattern: str, error: str, default: str | None = None) -> str:
    while True:
        value = Prompt.ask(prompt, default=default) if default else Prompt.ask(prompt)
        if re.fullmatch(pattern, value):
            return value
        console.print(f"[red]{error}[/]")


def ask_locale() -> str:
    supported = Path("/usr/share/i18n/SUPPORTED")
    lines = set(supported.read_text().splitlines()) if supported.exists() else set()
    while True:
        loc = ask_validated("Locale", r"[A-Za-z0-9_.@-]+", "Invalid locale syntax.",
                            "en_US.UTF-8")
        if not lines or f"{loc} UTF-8" in lines:
            return loc
        console.print(f"[red]Locale is not available: {loc}[/]")


def ask_timezone() -> str:
    while True:
        tz = ask_validated("Timezone", r"[A-Za-z0-9_+.-]+(/[A-Za-z0-9_+.-]+)*",
                           "Invalid timezone syntax.", "America/Santo_Domingo")
        if Path(f"/usr/share/zoneinfo/{tz}").is_file():
            return tz
        console.print(f"[red]Unknown timezone: {tz}[/]")


def ask_password() -> str:
    while True:
        pw = Prompt.ask("User password", password=True)
        if pw and pw == Prompt.ask("Repeat password", password=True):
            return pw
        console.print("[red]Passwords are empty or do not match.[/]")


# --------------------------------------------------------------------------
# banner
# --------------------------------------------------------------------------
def banner() -> None:
    text = "VEYRA OS"
    try:
        import pyfiglet  # optional
        text = pyfiglet.figlet_format("VEYRA", font="slant")
    except Exception:
        pass
    console.print(Panel.fit(f"[bold cyan]{text}[/]\n[dim]Guided installer[/]",
                            border_style="cyan"))
    console.print(f"[dim]Output is mirrored to {LOG_FILE}[/]")


# --------------------------------------------------------------------------
# install steps
# --------------------------------------------------------------------------
def prepare_keys_and_mirrors(hw: Hardware, use_v3: bool) -> None:
    step("Package keys and mirrors")
    run("systemctl start pacman-init.service", check=False, log=False)
    if not (Path("/etc/pacman.d/gnupg/pubring.kbx").exists()
            or Path("/etc/pacman.d/gnupg/pubring.gpg").exists()):
        run("pacman-key --init")
    run("pacman-key --populate archlinux cachyos")

    mirrorlist = Path("/etc/pacman.d/mirrorlist")
    backup = Path("/etc/pacman.d/mirrorlist.bak")
    backup.write_bytes(mirrorlist.read_bytes())
    console.print("Ranking Arch mirrors (this can take a minute)...")
    rc = run(["reflector", "--latest", "20", "--protocol", "https", "--sort", "rate",
              "--connection-timeout", "5", "--download-timeout", "5",
              "--save", str(mirrorlist)], check=False)
    if rc != 0:
        console.print("[yellow]Mirror ranking failed; keeping the default mirrorlist.[/]")
        mirrorlist.write_bytes(backup.read_bytes())

    if hw.v3:
        console.print("CPU supports x86-64-v3; using the CachyOS v3 mirrorlist.")
        conf = Path("/etc/pacman.conf")
        conf.write_text(conf.read_text().replace(
            "/etc/pacman.d/cachyos-mirrorlist", "/etc/pacman.d/cachyos-v3-mirrorlist"))
    else:
        console.print("CPU does not support x86-64-v3; using standard CachyOS packages.")
    run("pacman -Syy --noconfirm")


def ask_v3_kernel(hw: Hardware) -> bool:
    if not hw.v3:
        return False
    if not Confirm.ask("This CPU supports x86-64-v3. Install the optimized v3 kernel?",
                       default=False):
        return False
    console.print(Panel(
        "The v3 kernel will NOT boot on CPUs lacking x86-64-v3\n"
        "(AVX2, BMI1/2, FMA, MOVBE, LZCNT, F16C, ...).\n"
        "If this disk is ever moved to an older machine, it will not start.",
        title="Warning", border_style="red"))
    time.sleep(8)
    return Confirm.ask("Are you sure you want the v3 kernel?", default=False)


def partition_and_mount(disk: str, uefi: bool) -> tuple[str, str]:
    step("Partitioning")
    sep = "p" if Path(disk).name.startswith(("nvme", "mmcblk")) else ""
    boot_part, root = f"{disk}{sep}1", f"{disk}{sep}2"

    run(["sgdisk", "--zap-all", disk])
    if uefi:
        run(["sgdisk", "--new=1:0:+1GiB", "--typecode=1:ef00", "--change-name=1:VeyraEFI", disk])
    else:
        run(["sgdisk", "--new=1:0:+32MiB", "--typecode=1:ef02", "--change-name=1:VeyraBIOS", disk])
    run(["sgdisk", "--new=2:0:0", "--typecode=2:8300", "--change-name=2:VeyraRoot", disk])
    run(["blockdev", "--rereadpt", disk], check=False)
    run("udevadm settle")

    if uefi:
        run(["mkfs.fat", "-F32", "-n", "VEYRA_EFI", boot_part])
    run(["mkfs.btrfs", "-f", "-L", "VEYRA_ROOT", root])

    Path(MOUNT).mkdir(exist_ok=True)
    run(["mount", root, MOUNT])
    for sv in ("@", "@home", "@snapshots", "@var_log"):
        run(["btrfs", "subvolume", "create", f"{MOUNT}/{sv}"])
    run(["umount", MOUNT])

    run(["mount", "-o", f"{BTRFS_OPTS},subvol=@", root, MOUNT])
    for d in ("boot", "home", ".snapshots", "var/log"):
        Path(f"{MOUNT}/{d}").mkdir(parents=True, exist_ok=True)
    run(["mount", "-o", f"{BTRFS_OPTS},subvol=@home", root, f"{MOUNT}/home"])
    run(["mount", "-o", f"{BTRFS_OPTS},subvol=@snapshots", root, f"{MOUNT}/.snapshots"])
    run(["mount", "-o", f"{BTRFS_OPTS},subvol=@var_log", root, f"{MOUNT}/var/log"])
    if uefi:
        run(["mount", boot_part, f"{MOUNT}/boot"])
    return boot_part, root


def configure_system(cfg: dict) -> None:
    step("System configuration")
    m = Path(MOUNT)
    chroot("pacman-key", "--populate", "archlinux", "cachyos")

    (m / "etc/fstab").write_text(capture(["genfstab", "-U", MOUNT]))
    run(["install", "-Dm644", "/etc/pacman.conf", f"{MOUNT}/etc/pacman.conf"])
    run(["install", "-Dm644", "/etc/pacman.d/cachyos-mirrorlist",
         f"{MOUNT}/etc/pacman.d/cachyos-mirrorlist"])
    (m / "etc/hostname").write_text(cfg["hostname"] + "\n")

    locale_gen = m / "etc/locale.gen"
    wanted = f"{cfg['locale']} UTF-8"
    locale_gen.write_text("\n".join(
        line[1:] if line == f"#{wanted}" else line
        for line in locale_gen.read_text().splitlines()) + "\n")
    (m / "etc/locale.conf").write_text(f"LANG={cfg['locale']}\n")
    (m / "etc/vconsole.conf").write_text(f"KEYMAP={cfg['console_keymap']}\n")

    xorg = m / "etc/X11/xorg.conf.d"
    xorg.mkdir(parents=True, exist_ok=True)
    (xorg / "00-keyboard.conf").write_text(
        'Section "InputClass"\n'
        '    Identifier "system-keyboard"\n'
        '    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{cfg["xkb_layout"]}"\n'
        'EndSection\n')

    tz = m / "etc/localtime"
    tz.unlink(missing_ok=True)
    tz.symlink_to(f"/usr/share/zoneinfo/{cfg['timezone']}")

    chroot("locale-gen")
    chroot("useradd", "-m", "-G", "wheel", "-s", "/usr/bin/fish", cfg["username"])
    chroot("chpasswd", input_text=f"{cfg['username']}:{cfg['password']}\n")
    sudoers = m / "etc/sudoers.d/10-wheel"
    sudoers.write_text("%wheel ALL=(ALL:ALL) ALL\n")
    sudoers.chmod(0o440)
    chroot("systemctl", "enable", "NetworkManager", "sddm")
    chroot("systemctl", "set-default", "graphical.target")


def install_dotfiles(cfg: dict) -> None:
    step("Desktop configuration")
    user = shlex.quote(cfg["username"])
    chroot("bash", "-c",
           f"git clone --depth 1 {DOTFILES_URL} /tmp/dotfiles && "
           f"/tmp/dotfiles/setup.sh --config-only --user {user}; "
           "rm -rf /tmp/dotfiles")

    # The dotfiles hardcode kb_layout = "us"; apply the chosen layout.
    input_lua = Path(MOUNT) / "home" / cfg["username"] / ".config/hypr/modules/input.lua"
    if input_lua.exists():
        text = input_lua.read_text()
        input_lua.write_text(re.sub(r'kb_layout\s*=\s*"[^"]*"',
                                    f'kb_layout = "{cfg["xkb_layout"]}"', text))


def install_rivet(cfg: dict) -> None:
    if not os.access("/usr/local/bin/rivet", os.X_OK):
        return
    step("Rivet package manager")
    run(["install", "-Dm755", "/usr/local/bin/rivet", f"{MOUNT}/usr/local/bin/rivet"])
    if Path("/usr/share/rivet").is_dir():
        Path(f"{MOUNT}/usr/share/rivet").mkdir(parents=True, exist_ok=True)
        run(["cp", "-a", "/usr/share/rivet/.", f"{MOUNT}/usr/share/rivet/"])
    chroot("rivet", "init", "--system", check=False)
    chroot("sudo", "-u", cfg["username"], "rivet", "init", check=False)


def install_bootloader(disk: str, root: str, uefi: bool) -> None:
    step("Bootloader (Limine)")
    uuid = capture(["blkid", "-s", "UUID", "-o", "value", root]).strip()
    boot = Path(MOUNT) / "boot"
    (boot / "limine").mkdir(parents=True, exist_ok=True)
    (boot / "EFI/BOOT").mkdir(parents=True, exist_ok=True)

    conf = f"""timeout: 3
graphics: yes
interface_branding: Veyra OS

/Veyra OS (Linux CachyOS)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    module_path: boot():/initramfs-linux-cachyos.img
    cmdline: root=UUID={uuid} rootflags=subvol=@ rw quiet splash

/Veyra OS (Fallback Initramfs)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    module_path: boot():/initramfs-linux-cachyos-fallback.img
    cmdline: root=UUID={uuid} rootflags=subvol=@ rw
"""
    (boot / "limine/limine.conf").write_text(conf)
    (boot / "limine.conf").write_text(conf)

    if uefi:
        run(["cp", "/usr/share/limine/BOOTX64.EFI", str(boot / "EFI/BOOT/BOOTX64.EFI")])
        run(["cp", "/usr/share/limine/BOOTIA32.EFI", str(boot / "EFI/BOOT/BOOTIA32.EFI")])
        chroot("efibootmgr", "--create", "--disk", disk, "--part", "1",
               "--label", "Veyra OS (Limine)", "--loader", "\\EFI\\BOOT\\BOOTX64.EFI",
               check=False)
    else:
        run(["cp", "/usr/share/limine/limine-bios.sys", str(boot / "limine/")])
        run(["cp", "/usr/share/limine/limine-bios.sys", str(boot) + "/"])
        run(["limine", "bios-install", disk, "1"])

    chroot("systemctl", "enable", "limine-snapper-sync.service", check=False)


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
def main() -> int:
    if os.geteuid() != 0:
        console.print("[red]Run this installer as root.[/]")
        return 1
    if is_mounted(MOUNT):
        console.print(f"[red]{MOUNT} is already mounted; unmount it first.[/]")
        return 1

    uefi = Path("/sys/firmware/efi").is_dir()
    mounted = False
    try:
        banner()
        console.print(f"Firmware: [bold]{'UEFI' if uefi else 'Legacy BIOS'}[/]")

        step("Network")
        ensure_network()

        hw = detect_hardware()
        console.print(f"CPU: [bold]{hw.cpu_vendor}[/]   GPUs: [bold]"
                      f"{', '.join(hw.gpu_vendors) or 'none'}[/]   "
                      f"x86-64-v3: [bold]{'yes' if hw.v3 else 'no'}[/]")
        if "nvidia" in hw.gpu_vendors and not hw.nvidia_open:
            console.print("[yellow]Pre-Turing NVIDIA GPU found; leaving it on the nouveau driver.[/]")

        step("Setup questions")
        disk = pick_disk()
        username = ask_validated("Username", r"[a-z_][a-z0-9_-]*\$?",
                                 "Use a lowercase Linux username.")
        hostname = ask_validated("Hostname", r"[a-zA-Z0-9][a-zA-Z0-9-]{0,62}",
                                 "Invalid hostname.", "veyra")
        locale = ask_locale()
        timezone = ask_timezone()
        xkb_layout, console_keymap = ask_keyboard()
        password = ask_password()
        use_v3_kernel = ask_v3_kernel(hw)

        packages = BASE_PACKAGES + hw.extra_packages
        if not use_v3_kernel:
            # Force the generic kernel from the standard CachyOS repo.
            packages = [("cachyos/" + p) if p.startswith("linux-cachyos") else p
                        for p in packages]

        prepare_keys_and_mirrors(hw, use_v3_kernel)

        summary = Table(title="Summary", show_header=False)
        for k, v in (("Disk", disk), ("User", username), ("Hostname", hostname),
                     ("Locale", locale), ("Timezone", timezone),
                     ("Keyboard", f"{xkb_layout} (console: {console_keymap})"),
                     ("Kernel", "CachyOS v3" if use_v3_kernel else "CachyOS generic"),
                     ("Packages", str(len(packages))), ("Firmware", "UEFI" if uefi else "BIOS")):
            summary.add_row(k, v)
        console.print(summary)
        console.print(Panel(f"[bold red]{disk} will be completely erased.[/]",
                            border_style="red"))
        if Prompt.ask("Type ERASE to continue") != "ERASE":
            console.print("Confirmation did not match; no disk changes made.")
            return 1

        mounted = True
        _, root = partition_and_mount(disk, uefi)

        step("Installing packages (this takes a while)")
        run(["pacstrap", MOUNT, *packages])

        cfg = dict(username=username, hostname=hostname, locale=locale,
                   timezone=timezone, xkb_layout=xkb_layout,
                   console_keymap=console_keymap, password=password)
        configure_system(cfg)
        install_dotfiles(cfg)
        install_rivet(cfg)
        install_bootloader(disk, root, uefi)

        run(["umount", "-R", MOUNT])
        mounted = False
        console.print(Panel("[bold green]Veyra is installed.[/] Remove the ISO and reboot.",
                            border_style="green"))
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
            subprocess.run(["umount", "-R", MOUNT])


if __name__ == "__main__":
    sys.exit(main())