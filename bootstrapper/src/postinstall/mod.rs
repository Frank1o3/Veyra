//! Post-install configuration (OpenRC service enablement, elogind setup,
//! etc.). Not yet implemented.

use thiserror::Error;

#[derive(Debug, Error)]
pub enum PostInstallError {
    #[error("post-install configuration is not implemented yet")]
    NotImplemented,
}

pub fn run() -> Result<(), PostInstallError> {
    Err(PostInstallError::NotImplemented)
}
