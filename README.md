# Veyra OS ISO

Veyra is a small UEFI installation ISO built with Archiso. It boots to a live
Arch environment and starts a guided shell installer on the first console.
The live image includes only what is needed to boot, detect hardware, prepare
a disk, and install the base system.

## Build

On an Arch Linux or CachyOS build host, install `archiso`, `git`, `rate-mirrors`,
and the CachyOS repositories/package keyring required for `linux-cachyos`. The
build stages all four kernel caches by default and ranks Arch and CachyOS
mirrors into the ISO using the build host's network:

```sh
./build.sh
```

Choose a subset with `KERNEL_PROFILES`, a comma-separated list of `generic`,
`v3`, `v4`, and `znver4`, if needed:

```sh
KERNEL_PROFILES=generic,v3 ./build.sh
```

The build fetches optimized package archives but does not execute them on the
build host. Its temporary pacman config accepts the x86-64, v3, and v4 package
architectures, so producing the v4 and znver4 caches does not require a Zen 4/5
CPU or a special GitHub runner.

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
subvolumes, with Snapper snapshots nested under `@`. The ISO build uses the
generic CachyOS repository and kernel for the live environment, so it can boot
across supported x86-64 CPUs. It stages generic, x86-64-v3, x86-64-v4, and Zen
4/5 (`znver4`) CachyOS kernel archives and their dependencies in separate
preserved caches, with a matching system package cache for each profile. Each
kernel cache also carries firmware, Intel/AMD CPU microcode, Mesa/Vulkan graphics
drivers, NVIDIA open and proprietary driver packages, and their dependencies.
Each system package cache contains the installer's remaining packages and their
dependency archives from the corresponding generic, v3, v4, or znver4
repositories. Both cache types include local pacman repository databases and
`.files` indexes for the ISO's package snapshot. The v4 and znver4 repositories
use the CachyOS v4 mirrorlist, with znver4 using its own repo names. The
installer offers v4 only when glibc reports it supported and asks Intel users
to confirm AVX-512 works on all active cores.
It configures systemd as the init and service manager, and
uses Limine for UEFI boot. It enables NetworkManager and SDDM, installs the
Hyprland/Quickshell desktop packages, and creates the user in the `wheel` group
with Fish as the login shell. Limine waits five seconds and remembers the
previously selected kernel or snapshot for the next boot.

The installer offers the Zen 4/5 repository only on AMD systems and asks for
confirmation; it must only be selected for an AMD Zen 4 or Zen 5 CPU. The
x86-64-v3 profile is offered when the live system reports v3 support. CPU
microcode is selected from the detected vendor. `linux-firmware` pulls in the
vendor-split firmware packages, including AMD Radeon and Intel device firmware.
Intel and AMD graphics receive Mesa/Vulkan userspace packages. NVIDIA models
identified as RTX 3050 or newer use the open NVIDIA kernel module. Older RTX
models and supported GTX 900/750/16-series models use CachyOS's proprietary 580
driver package. Unidentified or unsupported older NVIDIA models remain on
Nouveau. Driver support depends on the exact GPU family supported by the
bundled 580 branch.

The installer uses the ranked mirrorlists bundled in the ISO when configuring
the installed system. If Wi-Fi is available, it can rank mirrors again, then
you can independently choose the ISO cache or network for kernel/drivers and
system packages. This allows cache/cache, cache/network, network/cache, or
network/network installs. With no network, both groups use the ISO snapshot.
Cache/cache installs need no package database refresh; mixed or network installs
use the ranked live repositories for package resolution. Offline installs
reproduce the ISO's package versions; update package databases and packages
after boot when networking is available. The selected disk is erased; back up
any data you need. Installer output is shown live and appended to
`/tmp/veyra-install.log`.
The ISO and installed package set explicitly include `libarchive`, which
provides `bsdtar` for package builds.

The installed system identifies itself as Veyra while retaining Arch Linux
compatibility metadata. Fastfetch uses a Veyra ASCII logo instead of selecting
the Arch logo from the base system.

## Desktop configuration

The build bundles the adjacent dotfiles checkout (override with
`DOTFILES_SOURCE`) into the ISO, excluding Neovim. The installer applies the
snapshot with `setup.sh --config-only`, so desktop configuration does not need
network access. This includes the animated notification toasts,
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
- `veyra-iso/airootfs/usr/local/lib/veyra/veyra-installer/src/veyra_installer/hardware.py`
  detects hardware and selects installed-system packages.
