"""Hardware detection: CPU vendor, GPUs, x86-64-v3 support, RAM size."""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from pathlib import Path

from .config import SWAP_ROUND_GIB, V3_FLAGS
from .shell import capture


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
            "dkms",
            "linux-cachyos-headers",
            "nvidia-open-dkms",
            "nvidia-utils",
            "lib32-nvidia-utils",
            "vulkan-icd-loader",
        ]
    hw.extra_packages = list(dict.fromkeys(hw.extra_packages))  # de-dupe, keep order
    return hw


def swap_size_mib() -> int:
    """Swap size for hibernation: RAM rounded UP to SWAP_ROUND_GIB.

    MemTotal is slightly below the physical RAM (the kernel reserves some), so
    rounding up gives a partition at least as large as the installed RAM.
    """
    kib = 0
    for line in Path("/proc/meminfo").read_text().splitlines():
        if line.startswith("MemTotal:"):
            kib = int(line.split()[1])
            break
    gib = math.ceil(kib / 1024 / 1024 / SWAP_ROUND_GIB) * SWAP_ROUND_GIB
    return gib * 1024