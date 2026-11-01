# Veyra OS ISO

Veyra is a small UEFI installation ISO built with Archiso. It boots to a live
Arch environment and starts a guided shell installer on the first console.
The live image includes only what is needed to boot, detect hardware, prepare
a disk, and install the base system.

## Build

On an Arch Linux or CachyOS build host, install `archiso`, `git`, and the
CachyOS repositories/package keyring required for `linux-cachyos`. Then run:

```sh
./build.sh
```

The ISO is written to `out/`. Archiso's temporary `work/` directory is removed
after a successful build.

Before distributing Veyra, review the [CachyOS repository usage policy](https://wiki.cachyos.org/policy/repository_policy/).
This profile installs packages from the CachyOS binary repository, whose
policy restricts use by other Arch-based distributions without authorization.

## Install

Boot the ISO in UEFI mode. The installer detects the CPU and PCI display
devices, lists available disks, and asks for an account, locale, time zone,
keyboard layout, and password. It shows the selected disk and package set
before requiring the exact word `ERASE`.

The installer creates a GPT disk with a 1 GiB EFI System Partition and a Btrfs
root partition. It creates `@`, `@home`, `@cache`, `@var_log`, and `@tmp`
subvolumes, with Snapper snapshots nested under `@`. The ISO build stages
generic, x86-64-v3, and Zen 4/5 (`znver4`) CachyOS kernel archives in a
preserved cache. The installer installs the selected profile's kernels and
their cached dependencies first, then installs the remaining package set
over the network. The live ISO itself continues to boot the generic kernel.
It configures systemd as the init and service manager, and
uses Limine for UEFI boot. It enables NetworkManager and SDDM, installs the
Hyprland/Quickshell desktop packages, and creates the user in the `wheel` group
with Fish as the login shell. Limine waits five seconds and remembers the
previously selected kernel or snapshot for the next boot.

The installer offers the Zen 4/5 repository only on AMD systems and asks for
confirmation; it must only be selected for an AMD Zen 4 or Zen 5 CPU. The
x86-64-v3 profile is offered when the live system reports v3 support. CPU
microcode is selected from the detected vendor. `linux-firmware` is the
firmware metapackage; it pulls in the vendor-split firmware packages, including
AMD Radeon and Intel device firmware as dependencies. Intel and AMD graphics
receive Mesa/Vulkan userspace packages. Turing and newer NVIDIA PCI device IDs
add the open kernel-module driver packages and CachyOS kernel headers. Older
NVIDIA hardware is left on the kernel's nouveau driver; install an appropriate
legacy driver manually if needed.

The installer requires a network connection because packages are downloaded
during installation. Connect Ethernet or configure Wi-Fi from another TTY
before continuing. The selected disk is erased; back up any data you need.
Installer output is shown live and appended to `/tmp/veyra-install.log`.
The ISO and installed package set explicitly include `libarchive`, which
provides `bsdtar` for package builds.

The installed system identifies itself as Veyra while retaining Arch Linux
compatibility metadata. Fastfetch uses a Veyra ASCII logo instead of selecting
the Arch logo from the base system.

## Desktop configuration

The installer installs the Hyprland, Quickshell, Kitty, Fish, Wallust, SDDM theme,
and wallpaper configuration directly from the [dotfiles repository](https://github.com/Frank1o3/dotfiles)
using `setup.sh --config-only`. This includes the animated notification toasts,
wallpaper picker, power menu and cheatsheet; the Settings page in Control Center;
and the Quickshell Polkit authentication dialog. The installer copies these into
the new user's home and enables SDDM. Polkit is installed as the system
authentication service, while Quickshell provides the desktop prompt. The
AUR-only Wallust executable and Catppuccin cursor package are not built during
installation; without Wallust, wallpaper changes still work but do not
regenerate the color palette.

## Layout

- `build.sh` builds the ISO with Archiso.
- `veyra-iso/` contains the Archiso profile and live-root shell scripts.
- `veyra-iso/airootfs/usr/local/bin/veyra-installer.py` is the guided installer.
- `veyra-iso/airootfs/usr/local/lib/veyra/hardware.sh` detects hardware and
  selects installed-system packages.
