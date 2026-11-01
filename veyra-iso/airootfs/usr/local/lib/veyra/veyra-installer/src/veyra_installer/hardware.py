"""Hardware detection: CPU vendor, GPUs, x86-64-v3 support, RAM size."""
from __future__ import annotations

import math
import re
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
    nvidia_proprietary: bool = False
    nvidia_model: str = "unknown"
    v3: bool = False
    v4: bool = False


def cpu_flags() -> set[str]:
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("flags"):
            return set(line.split(":", 1)[1].split())
    return set()


def supported_x86_64_levels() -> set[str]:
    """Return x86-64 ISA levels glibc reports as safe on this CPU."""
    # Preferred: ask glibc's loader. Fallback: check flags with the names
    # /proc/cpuinfo really uses (abm = lzcnt, pni = sse3).
    for loader in ("/lib64/ld-linux-x86-64.so.2", "/lib/ld-linux-x86-64.so.2"):
        if Path(loader).exists():
            out = capture([loader, "--help"])
            if out:
                return {
                    level
                    for level in ("v2", "v3", "v4")
                    if f"x86-64-{level} (supported, searched)" in out
                }
    # The loader output is unavailable: retain the existing v3 flag fallback.
    # v4 has no fallback because confirming the full AVX-512 feature set is
    # safer through glibc's own ISA-level check.
    return {"v3"} if set(V3_FLAGS) <= cpu_flags() else set()


def detect_hardware() -> Hardware:
    isa_levels = supported_x86_64_levels()
    hw = Hardware(v3="v3" in isa_levels, v4="v4" in isa_levels)

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
            # Match the requested RTX 3050 cutoff from the model name. PCI
            # device IDs are not monotonically ordered by product generation.
            label = capture(["lspci", "-s", dev.name]).strip()
            match = re.search(r"\b(RTX|GTX)\s*(\d{3,4})\b", label, re.IGNORECASE)
            if match:
                family, model = match.group(1).upper(), int(match.group(2))
                hw.nvidia_model = f"{family} {model}"
                if family == "RTX":
                    hw.nvidia_open |= model >= 3050
                    hw.nvidia_proprietary |= model < 3050
                elif model >= 900 or model == 750:
                    # The bundled proprietary 580 branch supports Maxwell and
                    # newer consumer cards. Kepler and older stay on Nouveau.
                    hw.nvidia_proprietary = True
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
            "lib32-vulkan-icd-loader",
        ]
    elif "nvidia" in hw.gpu_vendors and hw.nvidia_proprietary:
        hw.extra_packages += [
            "dkms",
            "linux-cachyos-headers",
            "nvidia-580xx-dkms",
            "nvidia-580xx-utils",
            "lib32-nvidia-580xx-utils",
            "vulkan-icd-loader",
            "lib32-vulkan-icd-loader",
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
