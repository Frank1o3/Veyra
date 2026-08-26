//! Bootloader configuration (Limine).
//!
//! Not yet implemented. When this is built, it must coordinate with
//! Btrfs snapshots explicitly rather than assuming a snapshot captures
//! the ESP/UEFI state -- see project rollback notes.

use thiserror::Error;

#[derive(Debug, Error)]
pub enum BootloaderError {
    #[error("bootloader configuration is not implemented yet")]
    NotImplemented,
}

pub fn install_and_configure() -> Result<(), BootloaderError> {
    Err(BootloaderError::NotImplemented)
}
