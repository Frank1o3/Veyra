//! Hardware profile model.
//!
//! Deliberately capability-based rather than a table of hardcoded machine
//! cases: a profile is derived from (CPU vendor, iGPU vendor, dGPU vendors),
//! and package selection reads off those fields. New hardware combinations
//! should fall out of this model automatically rather than requiring a new
//! hardcoded branch.

use serde::{Deserialize, Serialize};

use crate::hardware::HardwareInfo;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum GpuVendor {
    Intel,
    Amd,
    Nvidia,
    Other,
}

impl GpuVendor {
    /// PCI vendor IDs are stable and documented (pci-ids database).
    /// 0x8086 = Intel, 0x1002 = AMD/ATI, 0x10de = NVIDIA.
    pub fn from_pci_vendor_id(vendor_id: &str) -> Self {
        match vendor_id.trim_start_matches("0x").to_lowercase().as_str() {
            "8086" => GpuVendor::Intel,
            "1002" => GpuVendor::Amd,
            "10de" => GpuVendor::Nvidia,
            _ => GpuVendor::Other,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum NvidiaDriverChoice {
    /// nvidia-open: open-source kernel modules, proprietary userspace.
    /// Supported on Turing (GTX 16xx/RTX 20xx) and newer.
    Open,
    /// nvidia: fully proprietary driver, required for pre-Turing cards.
    Proprietary,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HardwareProfile {
    pub igpu: Option<GpuVendor>,
    pub dgpus: Vec<GpuVendor>,
    /// Only meaningful when an NVIDIA dGPU is present. Left unset until
    /// the user (or a generation-based heuristic, added later) chooses.
    pub nvidia_driver_choice: Option<NvidiaDriverChoice>,
}

impl HardwareProfile {
    pub fn from_hardware(info: &HardwareInfo) -> Self {
        let igpu = info
            .gpus
            .iter()
            .find(|g| g.is_likely_integrated)
            .map(|g| g.vendor);

        let dgpus: Vec<GpuVendor> = info
            .gpus
            .iter()
            .filter(|g| !g.is_likely_integrated)
            .map(|g| g.vendor)
            .collect();

        let nvidia_driver_choice = if dgpus.contains(&GpuVendor::Nvidia) {
            // Default to the open kernel modules; the profile/system-config
            // screen should let the user override this once we can query
            // GPU generation (e.g. via the pci-ids device name) to warn
            // when a card doesn't support the open modules.
            Some(NvidiaDriverChoice::Open)
        } else {
            None
        };

        HardwareProfile {
            igpu,
            dgpus,
            nvidia_driver_choice,
        }
    }

    /// Package set implied by this profile. Kept here (rather than in
    /// `install`) so the profile screen can show the user what will be
    /// installed before the install phase runs.
    pub fn graphics_packages(&self) -> Vec<&'static str> {
        let mut packages = Vec::new();

        if let Some(vendor) = self.igpu {
            packages.extend(Self::packages_for_vendor(vendor, false));
        }
        for &vendor in &self.dgpus {
            packages.extend(Self::packages_for_vendor(vendor, true));
        }

        packages.sort_unstable();
        packages.dedup();
        packages
    }

    fn packages_for_vendor(vendor: GpuVendor, is_discrete: bool) -> Vec<&'static str> {
        match vendor {
            GpuVendor::Intel => vec!["mesa", "vulkan-intel", "intel-media-driver"],
            GpuVendor::Amd => vec!["mesa", "vulkan-radeon", "libva-mesa-driver"],
            GpuVendor::Nvidia if is_discrete => {
                // Driver package name depends on nvidia_driver_choice; the
                // actual selection happens in `install`, which reads
                // `nvidia_driver_choice` directly. This still needs
                // resolving against the target kernel (linux-cachyos vs
                // linux-cachyos-lts) at install time, not here -- DKMS or
                // matching -headers package, decided during install
                // planning so kernel updates don't strand the module.
                vec!["vulkan-icd-loader"]
            }
            GpuVendor::Nvidia => vec![], // NVIDIA iGPU doesn't practically exist
            GpuVendor::Other => vec![],
        }
    }
}
