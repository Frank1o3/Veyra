//! Installation execution.
//!
//! Everything in this module is destructive and must only run during the
//! explicit installation phase (after the user has confirmed the final
//! plan), never as a side effect of a configuration screen.
//!
//! Not yet implemented -- this is a placeholder so `state`, `profiles`,
//! and `disk` have a defined consumer to design against. Filling this in
//! is the next major chunk of work after the screen flow itself works.

use crate::state::InstallState;

#[derive(Debug, thiserror::Error)]
pub enum InstallError {
    #[error("installation state is incomplete: missing {0:?}")]
    IncompleteState(Vec<&'static str>),
    #[error("installation is not implemented yet")]
    NotImplemented,
}

pub fn run(state: &InstallState) -> Result<(), InstallError> {
    if !state.is_ready_for_install() {
        return Err(InstallError::IncompleteState(state.missing_fields()));
    }

    // TODO, in rough order:
    //   1. Partition + format target disk per `state.disk_layout`.
    //   2. Mount target filesystems.
    //   3. Install base packages + `state.hardware_profile` graphics
    //      packages via pacstrap-equivalent, using structured argument
    //      lists (no shell string interpolation).
    //   4. Write fstab.
    //   5. Create user account (`useradd`/`chpasswd`-equivalent) using
    //      `state.account`, then drop the in-memory password.
    //   6. Apply `state.system` (locale, timezone, keyboard).
    //   7. Hand off to `bootloader` for Limine installation/configuration.
    //   8. Hand off to `postinstall` for OpenRC service enablement etc.
    Err(InstallError::NotImplemented)
}
