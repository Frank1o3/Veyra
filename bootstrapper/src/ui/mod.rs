//! TUI application: screen flow and input handling.
//!
//! `App` owns the `InstallState` plus purely UI-local data (which field
//! has focus, transient status messages, in-progress text buffers). No
//! function in this module ever touches disk, network, or system
//! accounts -- it only ever writes into `InstallState`. Rendering lives
//! in `ui::screens`; this file is the state machine and key handling.

mod screens;

use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::DefaultTerminal;
use std::time::Duration;

use crate::disk::{self, AvailableDisk, DiskLayout, PartitionScheme};
use crate::hardware;
use crate::install;
use crate::profiles::HardwareProfile;
use crate::state::InstallState;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Screen {
    Intro,
    Account,
    System,
    Profile,
    Disk,
    Install,
    Finalize,
}

impl Screen {
    fn next(self) -> Screen {
        match self {
            Screen::Intro => Screen::Account,
            Screen::Account => Screen::System,
            Screen::System => Screen::Profile,
            Screen::Profile => Screen::Disk,
            Screen::Disk => Screen::Install,
            Screen::Install => Screen::Finalize,
            Screen::Finalize => Screen::Finalize,
        }
    }

    fn prev(self) -> Screen {
        match self {
            Screen::Intro => Screen::Intro,
            Screen::Account => Screen::Intro,
            Screen::System => Screen::Account,
            Screen::Profile => Screen::System,
            Screen::Disk => Screen::Profile,
            Screen::Install => Screen::Disk,
            Screen::Finalize => Screen::Install,
        }
    }
}

/// Which text field on the current screen is receiving keystrokes.
/// Only meaningful on `Account` and `System` -- `Disk` is a selectable
/// list, not a text form, so it isn't driven by `Field`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Field {
    Username,
    Password,
    Hostname,
    Locale,
    Timezone,
    KeyboardLayout,
}

const ACCOUNT_FIELDS: [Field; 3] = [Field::Username, Field::Password, Field::Hostname];
const SYSTEM_FIELDS: [Field; 3] = [Field::Locale, Field::Timezone, Field::KeyboardLayout];

pub struct App {
    pub state: InstallState,
    pub screen: Screen,
    pub focus_index: usize,
    pub status: Option<String>,
    pub should_quit: bool,

    // Transient text buffers, separate from `InstallState` so a half-typed
    // value never leaks into state until the field is committed. Kept
    // simple (append/backspace only, no cursor movement) since this is a
    // skeleton -- a real line-editing widget can replace this later
    // without touching the state machine around it.
    username_buf: String,
    password_buf: String,
    hostname_buf: String,
    locale_buf: String,
    timezone_buf: String,
    keyboard_buf: String,

    // Disk screen: a live listing rather than free text, so the user can
    // only ever pick a real block device -- never a typo'd path pointing
    // at the wrong disk. `disks` is only populated by an explicit refresh
    // (never on a timer/automatically) so it's obvious to the user when
    // the list might be stale after e.g. plugging in a USB drive.
    pub disks: Vec<AvailableDisk>,
    pub disk_selected: usize,
}

impl App {
    pub fn new() -> Self {
        App {
            state: InstallState::default(),
            screen: Screen::Intro,
            focus_index: 0,
            status: None,
            should_quit: false,
            username_buf: String::new(),
            password_buf: String::new(),
            hostname_buf: String::new(),
            locale_buf: String::new(),
            timezone_buf: String::new(),
            keyboard_buf: String::new(),
            disks: Vec::new(),
            disk_selected: 0,
        }
    }

    fn fields_for_screen(&self) -> &'static [Field] {
        match self.screen {
            Screen::Account => &ACCOUNT_FIELDS,
            Screen::System => &SYSTEM_FIELDS,
            _ => &[],
        }
    }

    fn buffer_for(&mut self, field: Field) -> &mut String {
        match field {
            Field::Username => &mut self.username_buf,
            Field::Password => &mut self.password_buf,
            Field::Hostname => &mut self.hostname_buf,
            Field::Locale => &mut self.locale_buf,
            Field::Timezone => &mut self.timezone_buf,
            Field::KeyboardLayout => &mut self.keyboard_buf,
        }
    }

    fn buffer_ref(&self, field: Field) -> &str {
        match field {
            Field::Username => &self.username_buf,
            Field::Password => &self.password_buf,
            Field::Hostname => &self.hostname_buf,
            Field::Locale => &self.locale_buf,
            Field::Timezone => &self.timezone_buf,
            Field::KeyboardLayout => &self.keyboard_buf,
        }
    }

    fn current_field(&self) -> Option<Field> {
        self.fields_for_screen().get(self.focus_index).copied()
    }

    /// Commits every text buffer for the current screen into `state`.
    /// Called when the user advances past a screen, not on every
    /// keystroke -- state should only change at deliberate transitions.
    fn commit_screen(&mut self) {
        match self.screen {
            Screen::Account => {
                self.state.account.username = non_empty(&self.username_buf);
                self.state.account.password = non_empty(&self.password_buf);
                self.state.account.hostname = non_empty(&self.hostname_buf);
            }
            Screen::System => {
                self.state.system.locale = non_empty(&self.locale_buf);
                self.state.system.timezone = non_empty(&self.timezone_buf);
                self.state.system.keyboard_layout = non_empty(&self.keyboard_buf);
            }
            _ => {}
        }
    }

    fn advance(&mut self) {
        self.commit_screen();
        self.focus_index = 0;
        self.status = None;
        self.screen = self.screen.next();
    }

    fn retreat(&mut self) {
        self.focus_index = 0;
        self.status = None;
        self.screen = self.screen.prev();
    }

    fn handle_key(&mut self, code: KeyCode) {
        // Global keys, available from any screen.
        match code {
            KeyCode::Esc => {
                self.should_quit = true;
                return;
            }
            KeyCode::Left => {
                self.retreat();
                return;
            }
            _ => {}
        }

        match self.screen {
            Screen::Intro => {
                if let KeyCode::Enter = code {
                    self.advance();
                }
            }
            Screen::Account | Screen::System => {
                self.handle_form_key(code);
            }
            Screen::Profile => self.handle_profile_key(code),
            Screen::Disk => self.handle_disk_key(code),
            Screen::Install => self.handle_install_key(code),
            Screen::Finalize => {
                if let KeyCode::Enter = code {
                    self.should_quit = true;
                }
            }
        }
    }

    fn handle_form_key(&mut self, code: KeyCode) {
        let fields = self.fields_for_screen();
        if fields.is_empty() {
            return;
        }

        match code {
            KeyCode::Tab | KeyCode::Down => {
                self.focus_index = (self.focus_index + 1) % fields.len();
            }
            KeyCode::BackTab | KeyCode::Up => {
                self.focus_index = (self.focus_index + fields.len() - 1) % fields.len();
            }
            KeyCode::Char(c) => {
                if let Some(field) = self.current_field() {
                    self.buffer_for(field).push(c);
                }
            }
            KeyCode::Backspace => {
                if let Some(field) = self.current_field() {
                    self.buffer_for(field).pop();
                }
            }
            KeyCode::Enter => {
                // Enter on the last field advances; on earlier fields it
                // just moves focus forward, so pressing Enter repeatedly
                // walks the whole form like Tab does.
                if self.focus_index + 1 >= fields.len() {
                    self.advance();
                } else {
                    self.focus_index += 1;
                }
            }
            _ => {}
        }
    }

    fn handle_profile_key(&mut self, code: KeyCode) {
        match code {
            KeyCode::Char('d') | KeyCode::Char('D') => match hardware::detect() {
                Ok(info) => {
                    self.state.hardware_profile = Some(HardwareProfile::from_hardware(&info));
                    self.status = Some("Hardware detected.".to_string());
                }
                Err(e) => {
                    self.status = Some(format!("Detection failed: {e}"));
                }
            },
            KeyCode::Enter => {
                if self.state.hardware_profile.is_some() {
                    self.advance();
                } else {
                    self.status =
                        Some("Press 'd' to detect hardware before continuing.".to_string());
                }
            }
            _ => {}
        }
    }

    fn handle_disk_key(&mut self, code: KeyCode) {
        match code {
            KeyCode::Char('r') | KeyCode::Char('R') => match disk::list_available_disks() {
                Ok(disks) => {
                    let had_disks = !disks.is_empty();
                    self.disks = disks;
                    self.disk_selected = 0;
                    self.status = Some(if had_disks {
                        format!("Found {} disk(s).", self.disks.len())
                    } else {
                        "No disks found.".to_string()
                    });
                }
                Err(e) => {
                    self.status = Some(format!("Disk listing failed: {e}"));
                }
            },
            KeyCode::Down => {
                if !self.disks.is_empty() {
                    self.disk_selected = (self.disk_selected + 1) % self.disks.len();
                }
            }
            KeyCode::Up => {
                if !self.disks.is_empty() {
                    self.disk_selected =
                        (self.disk_selected + self.disks.len() - 1) % self.disks.len();
                }
            }
            KeyCode::Enter => {
                match self.disks.get(self.disk_selected) {
                    Some(chosen) => {
                        self.state.disk_layout = Some(DiskLayout {
                            target_disk: chosen.device_path.clone(),
                            scheme: PartitionScheme::ErasePlainBtrfs { esp_size_mib: 512 },
                        });
                        self.advance();
                    }
                    None => {
                        self.status =
                            Some("Press 'r' to list disks before choosing one.".to_string());
                    }
                }
            }
            _ => {}
        }
    }

    fn handle_install_key(&mut self, code: KeyCode) {
        if let KeyCode::Enter = code {
            match install::run(&self.state) {
                Ok(()) => self.advance(),
                Err(e) => self.status = Some(format!("{e}")),
            }
        }
    }
}

fn non_empty(s: &str) -> Option<String> {
    let trimmed = s.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

pub fn run(mut terminal: DefaultTerminal) -> std::io::Result<()> {
    let mut app = App::new();

    while !app.should_quit {
        terminal.draw(|frame| screens::render(frame, &app))?;

        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    app.handle_key(key.code);
                }
            }
        }
    }

    Ok(())
}
