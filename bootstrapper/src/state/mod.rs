//! Central installation state.
//!
//! This struct begins with empty/default values and is progressively
//! populated by each TUI screen. No screen performs destructive actions
//! directly -- they only write into this state. The `install` module is
//! solely responsible for acting on it, during the installation phase.

use serde::{Deserialize, Serialize};

use crate::disk::DiskLayout;
use crate::profiles::HardwareProfile;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct InstallState {
    pub account: AccountConfig,
    pub system: SystemConfig,
    pub hardware_profile: Option<HardwareProfile>,
    pub disk_layout: Option<DiskLayout>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AccountConfig {
    pub username: Option<String>,
    pub hostname: Option<String>,

    /// Plaintext password, held only for the duration of the install.
    /// Deliberately excluded from (de)serialization so that dumping
    /// `InstallState` (e.g. for debugging) never writes a password to disk.
    #[serde(skip)]
    pub password: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SystemConfig {
    pub locale: Option<String>,
    pub timezone: Option<String>,
    pub keyboard_layout: Option<String>,
}

impl InstallState {
    /// Returns the set of fields that still need to be filled in before
    /// installation can proceed. Screens use this to decide whether the
    /// user can advance past them.
    pub fn missing_fields(&self) -> Vec<&'static str> {
        let mut missing = Vec::new();

        if self.account.username.is_none() {
            missing.push("username");
        }
        if self.account.password.is_none() {
            missing.push("password");
        }
        if self.account.hostname.is_none() {
            missing.push("hostname");
        }
        if self.hardware_profile.is_none() {
            missing.push("hardware profile");
        }
        if self.disk_layout.is_none() {
            missing.push("disk layout");
        }

        missing
    }

    pub fn is_ready_for_install(&self) -> bool {
        self.missing_fields().is_empty()
    }
}
