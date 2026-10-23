#!/usr/bin/env bash

veyra_detect_hardware() {
    CPU_VENDOR=other
    GPU_VENDORS=()
    INSTALL_PACKAGES=()
    NVIDIA_OPEN_SUPPORTED=0

    if grep -q 'GenuineIntel' /proc/cpuinfo; then
        CPU_VENDOR=intel
        INSTALL_PACKAGES+=(intel-ucode)
    elif grep -q 'AuthenticAMD' /proc/cpuinfo; then
        CPU_VENDOR=amd
        INSTALL_PACKAGES+=(amd-ucode)
    fi

    local dev class vendor gpu device_id
    shopt -s nullglob
    for dev in /sys/bus/pci/devices/*; do
        [[ -r "$dev/class" ]] || continue
        class=$(<"$dev/class")
        [[ "$class" == 0x03* ]] || continue
        vendor=$(<"$dev/vendor")
        device_id=$(<"$dev/device")
        case "$vendor" in
            0x8086) gpu=intel ;;
            0x1002) gpu=amd ;;
            0x10de)
                gpu=nvidia
                # NVIDIA open kernel modules require Turing (device IDs
                # 1e00 and newer); Pascal and older need legacy drivers.
                if [[ "$device_id" =~ ^0x[[:xdigit:]]{4}$ ]] && (( 16#${device_id#0x} >= 0x1e00 )); then
                    NVIDIA_OPEN_SUPPORTED=1
                fi
                ;;
            *) gpu=other ;;
        esac
        [[ " ${GPU_VENDORS[*]} " == *" $gpu "* ]] || GPU_VENDORS+=("$gpu")
    done
    shopt -u nullglob

    if [[ " ${GPU_VENDORS[*]} " == *" intel "* ]]; then
        INSTALL_PACKAGES+=(mesa vulkan-intel intel-media-driver)
    fi
    if [[ " ${GPU_VENDORS[*]} " == *" amd "* ]]; then
        INSTALL_PACKAGES+=(mesa vulkan-radeon libva-mesa-driver)
    fi
    if (( NVIDIA_OPEN_SUPPORTED )); then
        INSTALL_PACKAGES+=(dkms linux-cachyos-headers nvidia-open-dkms nvidia-utils lib32-nvidia-utils vulkan-icd-loader)
    fi
}
