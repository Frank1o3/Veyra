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
root partition. It creates `@`, `@home`, `@snapshots`, and `@var_log`
subvolumes, installs the CachyOS kernel and firmware, and configures systemd as
the installed system's init and service manager, with systemd-boot for UEFI
boot. It enables NetworkManager and SDDM, installs the Hyprland/Quickshell
desktop packages, and creates the user in the `wheel` group with Fish as the
login shell.

CPU microcode is selected from the detected vendor. `linux-firmware` is the
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

## Desktop configuration

The ISO bundles the Hyprland, Quickshell, Kitty, Fish, Wallust, SDDM theme,
and wallpaper configuration from the [dotfiles repository](https://github.com/Frank1o3/dotfiles).
The installer copies these into the new user's home and enables SDDM. Neovim
configuration and packages are not included. The AUR-only Wallust executable
and Catppuccin cursor package are not built during installation; without
Wallust, wallpaper changes still work but do not regenerate the color palette.

## Layout

- `build.sh` builds the ISO with Archiso.
- `veyra-iso/` contains the Archiso profile and live-root shell scripts.
- `veyra-iso/airootfs/usr/local/bin/veyra-installer.sh` is the guided installer.
- `veyra-iso/airootfs/usr/local/lib/veyra/hardware.sh` detects hardware and
  selects installed-system packages.
- `veyra-iso/airootfs/usr/local/lib/veyra/install-dotfiles.sh` installs the
  bundled desktop configuration into the target user account.
