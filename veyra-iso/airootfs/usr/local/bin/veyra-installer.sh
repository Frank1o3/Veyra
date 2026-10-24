#!/usr/bin/env bash
set -Eeuo pipefail

source /usr/local/lib/veyra/hardware.sh
LOG_FILE=/tmp/veyra-install.log
exec > >(tee -a "$LOG_FILE") 2>&1

MOUNT=/mnt
MOUNTED=0
cleanup() {
    if (( MOUNTED )) && mountpoint -q "$MOUNT"; then
        umount -R "$MOUNT" || true
    fi
}
trap cleanup EXIT

fail() { printf '\nInstaller stopped: %s\n' "$*" >&2; }
need_root() {
    if (( EUID != 0 )); then
        fail "run this installer as root"
        exit 1
    fi
}
ask() {
    local prompt=$1 value
    read -r -p "$prompt" value
    REPLY=$value
}

have_network() {
    ping -c1 -W3 archlinux.org >/dev/null 2>&1 \
        || curl -fsI --max-time 5 https://archlinux.org >/dev/null 2>&1
}

ensure_network() {
    systemctl start NetworkManager.service 2>/dev/null || true
    rfkill unblock wifi 2>/dev/null || true
    sleep 2
    until have_network; do
        printf '\nNo internet connection detected.\n'
        printf '  1) Open network setup (nmtui)\n'
        printf '  2) Retry connection check\n'
        printf '  3) Quit installer\n'
        ask 'Choose [1]: '
        case "${REPLY:-1}" in
            1) nmtui </dev/tty >/dev/tty 2>&1 || true; sleep 3 ;;
            2) ;;
            3) exit 1 ;;
            *) printf 'Invalid choice.\n' ;;
        esac
    done
    printf 'Network connection OK.\n'
}

need_root
IS_UEFI=0
[[ -d /sys/firmware/efi ]] && IS_UEFI=1
if mountpoint -q "$MOUNT"; then
    fail "$MOUNT is already mounted; unmount it before starting the installer"
    exit 1
fi
veyra_detect_hardware

clear || true
cat <<'WELCOME'
Veyra OS installer
==================
This installs a minimal CachyOS-kernel Arch system with the Limine bootloader.
The selected disk will be erased after the final confirmation.
Output is mirrored to /tmp/veyra-install.log.
WELCOME
if (( IS_UEFI )); then
    printf '\nDetected Firmware: UEFI (x86_64 / IA32 supported)\n'
else
    printf '\nDetected Firmware: Legacy BIOS\n'
fi
printf '\nDetected CPU: %s\n' "$CPU_VENDOR"
printf 'Detected GPUs: %s\n' "${GPU_VENDORS[*]:-none}"
if [[ " ${GPU_VENDORS[*]} " == *" nvidia "* ]] && (( ! NVIDIA_OPEN_SUPPORTED )); then
    printf 'NVIDIA driver: pre-Turing hardware found; leaving it on the kernel nouveau driver.\n'
fi
ensure_network
mapfile -t DISKS < <(lsblk -dnpo NAME,SIZE,MODEL,TYPE | awk '$(NF) == "disk" { $NF=""; sub(/[[:space:]]+$/, ""); print }')
if ((${#DISKS[@]} == 0)); then
    fail "no install disks were found"
    exit 1
fi
printf '\nInstall target disks:\n'
for i in "${!DISKS[@]}"; do printf '  %d) %s\n' "$((i + 1))" "${DISKS[$i]}"; done
ask 'Choose a disk number: '
[[ "$REPLY" =~ ^[0-9]+$ ]] || { fail 'invalid disk selection'; exit 1; }
DISK_CHOICE=$((10#$REPLY))
(( DISK_CHOICE >= 1 && DISK_CHOICE <= ${#DISKS[@]} )) || { fail 'invalid disk selection'; exit 1; }
DISK=$(awk '{print $1}' <<<"${DISKS[$((DISK_CHOICE - 1))]}")

ask 'Username: '
USERNAME=$REPLY
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || { fail 'use a lowercase Linux username'; exit 1; }
ask 'Hostname [veyra]: '
HOSTNAME=${REPLY:-veyra}
[[ "$HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || { fail 'invalid hostname'; exit 1; }
ask 'Locale [en_US.UTF-8]: '
LOCALE=${REPLY:-en_US.UTF-8}
[[ "$LOCALE" =~ ^[A-Za-z0-9_.@-]+$ ]] || { fail 'invalid locale syntax'; exit 1; }
grep -Fxq "$LOCALE UTF-8" /usr/share/i18n/SUPPORTED || { fail "locale is not available: $LOCALE"; exit 1; }
ask 'Timezone [America/Santo_Domingo]: '
TIMEZONE=${REPLY:-America/Santo_Domingo}
[[ "$TIMEZONE" =~ ^[A-Za-z0-9_+.-]+(/[A-Za-z0-9_+.-]+)*$ ]] || { fail 'invalid timezone syntax'; exit 1; }
[[ -f "/usr/share/zoneinfo/$TIMEZONE" ]] || { fail "unknown timezone: $TIMEZONE"; exit 1; }
ask 'Keyboard layout [us]: '
KEYMAP=${REPLY:-us}
[[ "$KEYMAP" =~ ^[A-Za-z0-9_+-]+$ ]] || { fail 'invalid keyboard layout syntax'; exit 1; }
find /usr/share/kbd/keymaps -type f -name "$KEYMAP.map*" -print -quit | grep -q . || { fail "unknown keyboard layout: $KEYMAP"; exit 1; }
read -r -s -p 'User password: ' PASSWORD; printf '\n'
read -r -s -p 'Repeat password: ' PASSWORD_CONFIRM; printf '\n'
[[ -n "$PASSWORD" && "$PASSWORD" == "$PASSWORD_CONFIRM" ]] || { fail 'passwords are empty or do not match'; exit 1; }
unset PASSWORD_CONFIRM

BASE_PACKAGES=(
    base linux-cachyos linux-firmware cachyos-keyring cachyos-mirrorlist
    btrfs-progs networkmanager sudo git nano fish cachyos-fish-config
    hyprland hyprlock hypridle hyprshutdown hyprpolkitagent quickshell sddm
    kitty awww
    pipewire pipewire-pulse wireplumber
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    gnome-keyring nm-connection-editor network-manager-applet
    brightnessctl playerctl thunar gvfs tumbler file-roller
    adw-gtk-theme papirus-icon-theme adwaita-cursors
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common
    qt6ct qt6-5compat python rsync
    limine limine-mkinitcpio-hook limine-snapper-sync snapper efibootmgr cava inter-font
)
PACKAGES=("${BASE_PACKAGES[@]}" "${INSTALL_PACKAGES[@]}")
PACKAGES=("${PACKAGES[@]/#linux-cachyos/${KERNEL_PREFIX}linux-cachyos}")
printf '\nPackages to install:\n  %s\n' "${PACKAGES[*]}"
printf '\nTarget: %s\nHostname: %s\nUser: %s\n' "$DISK" "$HOSTNAME" "$USERNAME"
printf '\nPreparing package keys and checking repository access...\n'

systemctl start pacman-init.service || true
if [[ ! -s /etc/pacman.d/gnupg/pubring.gpg && ! -s /etc/pacman.d/gnupg/pubring.kbx ]]; then
    pacman-key --init
fi
pacman-key --populate archlinux cachyos

printf '\nRanking Arch mirrors (this can take a minute)...\n'
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
if reflector --latest 20 --protocol https --sort rate \
        --connection-timeout 5 --download-timeout 5 \
        --save /etc/pacman.d/mirrorlist; then
    printf 'Mirrorlist updated.\n'
else
    printf 'Mirror ranking failed; keeping the default mirrorlist.\n'
    cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
fi

USE_V3_KERNEL=0
if [[ "$KERNEL_REPOSITORY" == cachyos-v3 ]]; then
    ask 'This CPU supports x86-64-v3. Install the optimized v3 kernel? [y/N]: '
    if [[ "${REPLY,,}" == y* ]]; then
        printf '\nWARNING: the v3 kernel will NOT boot on CPUs lacking\n'
        printf 'x86-64-v3 (AVX2, BMI1/2, FMA, MOVBE, LZCNT, F16C, ...).\n'
        printf 'If this disk is ever moved to an older machine, it will not start.\n\n'
        sleep 8
        ask 'Are you sure you want the v3 kernel? [y/N]: '
        [[ "${REPLY,,}" == y* ]] && USE_V3_KERNEL=1
    fi
fi
KERNEL_PREFIX=""
(( USE_V3_KERNEL )) || KERNEL_PREFIX="cachyos/"

read -r -p "Type ERASE to partition and format $DISK: " CONFIRM
[[ "$CONFIRM" == ERASE ]] || { fail 'confirmation did not match; no disk changes made'; exit 1; }

for part in $(lsblk -nrpo NAME "$DISK" | tail -n +2); do
    if findmnt -rn "$part" >/dev/null; then
        fail "$part is mounted; unmount it before installing"
        exit 1
    fi
done

case "$(basename "$DISK")" in nvme*|mmcblk*) SEP=p ;; *) SEP= ;; esac
BOOT_PART="${DISK}${SEP}1"
ROOT="${DISK}${SEP}2"

sgdisk --zap-all "$DISK"
if (( IS_UEFI )); then
    sgdisk --new=1:0:+1GiB --typecode=1:ef00 --change-name=1:VeyraEFI "$DISK"
else
    # 32MiB BIOS boot partition for Limine stage 2 on GPT
    sgdisk --new=1:0:+32MiB --typecode=1:ef02 --change-name=1:VeyraBIOS "$DISK"
fi
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:VeyraRoot "$DISK"
blockdev --rereadpt "$DISK"
udevadm settle

if (( IS_UEFI )); then
    mkfs.fat -F32 -n VEYRA_EFI "$BOOT_PART"
fi
mkfs.btrfs -f -L VEYRA_ROOT "$ROOT"

mkdir -p "$MOUNT"
MOUNTED=1
mount "$ROOT" "$MOUNT"
btrfs subvolume create "$MOUNT/@"
btrfs subvolume create "$MOUNT/@home"
btrfs subvolume create "$MOUNT/@snapshots"
btrfs subvolume create "$MOUNT/@var_log"
umount "$MOUNT"
mount -o noatime,compress=zstd:3,space_cache=v2,subvol=@ "$ROOT" "$MOUNT"
mkdir -p "$MOUNT"/{boot,home,.snapshots,var/log}
mount -o noatime,compress=zstd:3,space_cache=v2,subvol=@home "$ROOT" "$MOUNT/home"
mount -o noatime,compress=zstd:3,space_cache=v2,subvol=@snapshots "$ROOT" "$MOUNT/.snapshots"
mount -o noatime,compress=zstd:3,space_cache=v2,subvol=@var_log "$ROOT" "$MOUNT/var/log"

if (( IS_UEFI )); then
    mount "$BOOT_PART" "$MOUNT/boot"
fi


pacman -Syy --noconfirm
pacstrap "$MOUNT" "${PACKAGES[@]}"
arch-chroot "$MOUNT" pacman-key --populate archlinux cachyos
genfstab -U "$MOUNT" > "$MOUNT/etc/fstab"
install -Dm644 /etc/pacman.conf "$MOUNT/etc/pacman.conf"
install -Dm644 /etc/pacman.d/cachyos-mirrorlist "$MOUNT/etc/pacman.d/cachyos-mirrorlist"
printf '%s\n' "$HOSTNAME" > "$MOUNT/etc/hostname"
awk -v target="#${LOCALE} UTF-8" '$0 == target { sub(/^#/, "") } { print }' "$MOUNT/etc/locale.gen" > "$MOUNT/etc/locale.gen.tmp"
mv "$MOUNT/etc/locale.gen.tmp" "$MOUNT/etc/locale.gen"
printf 'LANG=%s\n' "$LOCALE" > "$MOUNT/etc/locale.conf"
printf 'KEYMAP=%s\n' "$KEYMAP" > "$MOUNT/etc/vconsole.conf"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$MOUNT/etc/localtime"
arch-chroot "$MOUNT" locale-gen
arch-chroot "$MOUNT" useradd -m -G wheel -s /usr/bin/fish "$USERNAME"
printf '%s:%s\n' "$USERNAME" "$PASSWORD" | arch-chroot "$MOUNT" chpasswd
unset PASSWORD
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$MOUNT/etc/sudoers.d/10-wheel"
chmod 0440 "$MOUNT/etc/sudoers.d/10-wheel"
arch-chroot "$MOUNT" systemctl enable NetworkManager sddm
arch-chroot "$MOUNT" systemctl set-default graphical.target

printf '\nInstalling desktop configuration from dotfiles repository...\n'
arch-chroot "$MOUNT" bash -c "
    git clone --depth 1 https://github.com/Frank1o3/dotfiles.git /tmp/dotfiles
    /tmp/dotfiles/setup.sh --config-only --user '$USERNAME'
    rm -rf /tmp/dotfiles
"

if [[ -x /usr/local/bin/rivet ]]; then
    printf '\nInstalling Rivet package manager...\n'
    install -Dm755 /usr/local/bin/rivet "$MOUNT/usr/local/bin/rivet"
    if [[ -d /usr/share/rivet ]]; then
        mkdir -p "$MOUNT/usr/share/rivet"
        cp -a /usr/share/rivet/. "$MOUNT/usr/share/rivet/"
    fi
    arch-chroot "$MOUNT" rivet init --system 2>/dev/null || true
    arch-chroot "$MOUNT" sudo -u "$USERNAME" rivet init 2>/dev/null || true
fi
printf '\nConfiguring Limine bootloader...\n'
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")

install -d "$MOUNT/boot/limine" "$MOUNT/boot/EFI/BOOT"

cat > "$MOUNT/boot/limine/limine.conf" <<EOF
timeout: 3
graphics: yes
interface_branding: Veyra OS

/Veyra OS (Linux CachyOS)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    module_path: boot():/initramfs-linux-cachyos.img
    cmdline: root=UUID=$ROOT_UUID rootflags=subvol=@ rw quiet splash

/Veyra OS (Fallback Initramfs)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    module_path: boot():/initramfs-linux-cachyos-fallback.img
    cmdline: root=UUID=$ROOT_UUID rootflags=subvol=@ rw
EOF

cp "$MOUNT/boot/limine/limine.conf" "$MOUNT/boot/limine.conf"

if (( IS_UEFI )); then
    # Deploy UEFI binaries (both x86_64 and 32-bit IA32 for mixed-mode)
    cp /usr/share/limine/BOOTX64.EFI "$MOUNT/boot/EFI/BOOT/BOOTX64.EFI"
    cp /usr/share/limine/BOOTIA32.EFI "$MOUNT/boot/EFI/BOOT/BOOTIA32.EFI"
    arch-chroot "$MOUNT" efibootmgr --create --disk "$DISK" --part 1 --label "Veyra OS (Limine)" --loader "\\EFI\\BOOT\\BOOTX64.EFI" 2>/dev/null || true
else
    # Deploy Legacy BIOS Limine
    cp /usr/share/limine/limine-bios.sys "$MOUNT/boot/limine/"
    cp /usr/share/limine/limine-bios.sys "$MOUNT/boot/"
    limine bios-install "$DISK" 1
fi

arch-chroot "$MOUNT" systemctl enable limine-snapper-sync.service 2>/dev/null || true

umount -R "$MOUNT"
MOUNTED=0
trap - EXIT
printf '\nVeyra is installed. Remove the ISO and reboot.\n'
read -r -p 'Press Enter to return to the live system. '
