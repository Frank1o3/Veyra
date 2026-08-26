//! Hardware detection.
//!
//! Reads CPU vendor and PCI display-class devices directly from sysfs
//! rather than shelling out to and parsing `lspci` text output. PCI
//! class `0x03xxxx` covers VGA/3D/display controllers, which is how we
//! find iGPUs and dGPUs without hardcoding device IDs.

use std::fs;
use std::path::Path;
use thiserror::Error;

use crate::profiles::GpuVendor;

#[derive(Debug, Error)]
pub enum HardwareError {
    #[error("failed to read {path}: {source}")]
    ReadFailed {
        path: String,
        #[source]
        source: std::io::Error,
    },
    #[error("/sys/bus/pci/devices was not found -- are we running on Linux with sysfs mounted?")]
    NoSysfs,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DetectedGpu {
    pub vendor: GpuVendor,
    /// PCI vendor:device id, e.g. "8086:9a49". Useful for logging/debugging
    /// even though profile selection should key off `vendor`, not this.
    pub pci_id: String,
    /// True if this device is integrated into the CPU package (heuristic:
    /// vendor is Intel or AMD and it's the only display controller on the
    /// CPU's own PCI bus). This is refined by the profile layer, not here.
    pub is_likely_integrated: bool,
}

#[derive(Debug, Clone)]
pub struct HardwareInfo {
    pub cpu_vendor: CpuVendor,
    pub gpus: Vec<DetectedGpu>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CpuVendor {
    Intel,
    Amd,
    Other,
}

const PCI_DEVICES_PATH: &str = "/sys/bus/pci/devices";
const CPU_VENDOR_PATH: &str = "/proc/cpuinfo";

/// PCI base class for display controllers (VGA, XGA, 3D, other).
const DISPLAY_CONTROLLER_CLASS_PREFIX: &str = "0x03";

pub fn detect() -> Result<HardwareInfo, HardwareError> {
    Ok(HardwareInfo {
        cpu_vendor: detect_cpu_vendor()?,
        gpus: detect_gpus()?,
    })
}

fn detect_cpu_vendor() -> Result<CpuVendor, HardwareError> {
    let contents =
        fs::read_to_string(CPU_VENDOR_PATH).map_err(|source| HardwareError::ReadFailed {
            path: CPU_VENDOR_PATH.to_string(),
            source,
        })?;

    let vendor_line = contents
        .lines()
        .find(|line| line.starts_with("vendor_id"))
        .unwrap_or("");

    if vendor_line.contains("GenuineIntel") {
        Ok(CpuVendor::Intel)
    } else if vendor_line.contains("AuthenticAMD") {
        Ok(CpuVendor::Amd)
    } else {
        Ok(CpuVendor::Other)
    }
}

fn detect_gpus() -> Result<Vec<DetectedGpu>, HardwareError> {
    let devices_dir = Path::new(PCI_DEVICES_PATH);
    if !devices_dir.is_dir() {
        return Err(HardwareError::NoSysfs);
    }

    let mut gpus = Vec::new();

    for entry in fs::read_dir(devices_dir).map_err(|source| HardwareError::ReadFailed {
        path: PCI_DEVICES_PATH.to_string(),
        source,
    })? {
        let entry = match entry {
            Ok(e) => e,
            Err(_) => continue,
        };
        let device_path = entry.path();

        let class = match read_hex_attr(&device_path, "class") {
            Some(c) => c,
            None => continue,
        };
        if !class.starts_with(DISPLAY_CONTROLLER_CLASS_PREFIX) {
            continue;
        }

        let vendor_id = match read_hex_attr(&device_path, "vendor") {
            Some(v) => v,
            None => continue,
        };
        let device_id = match read_hex_attr(&device_path, "device") {
            Some(d) => d,
            None => continue,
        };

        let vendor = GpuVendor::from_pci_vendor_id(&vendor_id);
        let pci_id = format!(
            "{}:{}",
            vendor_id.trim_start_matches("0x"),
            device_id.trim_start_matches("0x")
        );

        // Heuristic only: real integrated-vs-discrete disambiguation on
        // multi-GPU vendor systems (e.g. AMD APU + AMD dGPU) needs more
        // than this and should be refined in `profiles` once we have
        // real hardware to test against.
        let is_likely_integrated = matches!(vendor, GpuVendor::Intel)
            || (matches!(vendor, GpuVendor::Amd) && gpus.is_empty());

        gpus.push(DetectedGpu {
            vendor,
            pci_id,
            is_likely_integrated,
        });
    }

    Ok(gpus)
}

fn read_hex_attr(device_path: &Path, attr: &str) -> Option<String> {
    fs::read_to_string(device_path.join(attr))
        .ok()
        .map(|s| s.trim().to_string())
}
