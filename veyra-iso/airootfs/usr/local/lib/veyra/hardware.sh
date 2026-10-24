#!/usr/bin/env bash

veyra_detect_hardware() {
    CPU_VENDOR=other
    GPU_VENDORS=()
    INSTALL_PACKAGES=()
    NVIDIA_OPEN_SUPPORTED=0
    
    local ldso_out cpu_flags flag
    KERNEL_REPOSITORY=cachyos

    # Preferred: ask glibc's loader. Captured to a variable (not piped to
    # grep -q) so pipefail/SIGPIPE can't cause a false negative.
    ldso_out=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null || true)
    if [[ "$ldso_out" == *"x86-64-v3 (supported, searched)"* ]]; then
        KERNEL_REPOSITORY=cachyos-v3
    elif [[ -z "$ldso_out" ]]; then
        # Fallback: manual flag check using the names /proc/cpuinfo really uses
        # (abm = lzcnt, pni = sse3).
        cpu_flags=$(sed -n 's/^flags[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -n 1)
        KERNEL_REPOSITORY=cachyos-v3
        for flag in avx avx2 bmi1 bmi2 f16c fma abm movbe xsave \
                    cx16 lahf_lm popcnt pni ssse3 sse4_1 sse4_2; do
            if [[ " $cpu_flags " != *" $flag "* ]]; then
                KERNEL_REPOSITORY=cachyos
                break
            fi
        done
    fi

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
