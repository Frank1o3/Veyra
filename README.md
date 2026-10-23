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
boot. It enables NetworkManager and creates the user in the `wheel` group.

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

## Desktop setup

The [dotfiles repository](https://github.com/Frank1o3/dotfiles) is a personal
Hyprland/Quickshell configuration. Its `setup.sh` expects `paru` and builds
some AUR packages, so the ISO does not run it as root during OS installation.
After first boot, install the build tools and paru, then run the setup as the
new user:

```sh
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git
cd paru && makepkg -si
cd ..
git clone https://github.com/Frank1o3/dotfiles.git
cd dotfiles && ./setup.sh
```

## Layout

- `build.sh` builds the ISO with Archiso.
- `veyra-iso/` contains the Archiso profile and live-root shell scripts.
- `veyra-iso/airootfs/usr/local/bin/veyra-installer.sh` is the guided installer.
- `veyra-iso/airootfs/usr/local/lib/veyra/hardware.sh` detects hardware and
  selects installed-system packages.
