//! Pure rendering. Nothing here mutates `App` -- these functions only
//! read it and draw. Keeping render separate from `ui::mod`'s state
//! machine means the screen flow logic stays testable without a terminal.

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph};
use ratatui::Frame;

use super::{App, Field, Screen};

pub fn render(frame: &mut Frame, app: &App) {
    let area = frame.area();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // header / step indicator
            Constraint::Min(0),    // screen content
            Constraint::Length(3), // footer / key hints
        ])
        .split(area);

    render_header(frame, chunks[0], app.screen);
    render_body(frame, chunks[1], app);
    render_footer(frame, chunks[2], app);
}

fn render_header(frame: &mut Frame, area: Rect, screen: Screen) {
    let steps = [
        ("1", "Intro", Screen::Intro),
        ("2", "Account", Screen::Account),
        ("3", "System", Screen::System),
        ("4", "Profile", Screen::Profile),
        ("5", "Disk", Screen::Disk),
        ("6", "Install", Screen::Install),
        ("7", "Finalize", Screen::Finalize),
    ];

    let mut spans = Vec::new();
    for (n, label, s) in steps {
        let style = if s == screen {
            Style::default()
                .fg(Color::Black)
                .bg(Color::Cyan)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(Color::DarkGray)
        };
        spans.push(Span::styled(format!(" {n}:{label} "), style));
    }

    let title = Paragraph::new(Line::from(spans))
        .block(Block::default().borders(Borders::ALL).title("Veyra OS Installer"));
    frame.render_widget(title, area);
}

fn render_footer(frame: &mut Frame, area: Rect, app: &App) {
    let hint = match app.screen {
        Screen::Intro => "Enter: continue   Esc: quit",
        Screen::Account | Screen::System => {
            "Tab/Down: next field   Enter: next field (or continue on last)   Esc: quit   Left: back"
        }
        Screen::Profile => "d: detect hardware   Enter: continue   Esc: quit   Left: back",
        Screen::Disk => "r: list disks   Up/Down: select   Enter: choose & continue   Esc: quit   Left: back",
        Screen::Install => "Enter: run install   Esc: quit   Left: back",
        Screen::Finalize => "Enter: exit",
    };

    let mut lines = vec![Line::from(hint)];
    if let Some(status) = &app.status {
        lines.push(Line::from(Span::styled(
            status.clone(),
            Style::default().fg(Color::Yellow),
        )));
    }

    let footer = Paragraph::new(lines).block(Block::default().borders(Borders::ALL));
    frame.render_widget(footer, area);
}

fn render_body(frame: &mut Frame, area: Rect, app: &App) {
    match app.screen {
        Screen::Intro => render_intro(frame, area),
        Screen::Account => render_form(
            frame,
            area,
            "Account",
            &[
                (Field::Username, "Username", app.buffer_ref(Field::Username)),
                (Field::Password, "Password", app.buffer_ref(Field::Password)),
                (Field::Hostname, "Hostname", app.buffer_ref(Field::Hostname)),
            ],
            app.focus_index,
            app.screen == Screen::Account,
        ),
        Screen::System => render_form(
            frame,
            area,
            "System configuration",
            &[
                (Field::Locale, "Locale (e.g. en_US.UTF-8)", app.buffer_ref(Field::Locale)),
                (Field::Timezone, "Timezone (e.g. Europe/Berlin)", app.buffer_ref(Field::Timezone)),
                (Field::KeyboardLayout, "Keyboard layout (e.g. us)", app.buffer_ref(Field::KeyboardLayout)),
            ],
            app.focus_index,
            app.screen == Screen::System,
        ),
        Screen::Profile => render_profile(frame, area, app),
        Screen::Disk => render_disk(frame, area, app),
        Screen::Install => render_install(frame, area, app),
        Screen::Finalize => render_finalize(frame, area),
    }
}

fn render_intro(frame: &mut Frame, area: Rect) {
    let text = vec![
        Line::from("Welcome to the Veyra OS installer."),
        Line::from(""),
        Line::from("This will walk you through configuring and installing Veyra."),
        Line::from("Nothing on this machine is changed until you confirm the"),
        Line::from("final installation plan on the Install screen."),
    ];
    let p = Paragraph::new(text).block(Block::default().borders(Borders::ALL).title("Introduction"));
    frame.render_widget(p, area);
}

/// Renders a simple list of labeled text fields, masking the value for
/// any field literally named "Password".
fn render_form(
    frame: &mut Frame,
    area: Rect,
    title: &str,
    fields: &[(Field, &str, &str)],
    focus_index: usize,
    focused: bool,
) {
    let mut lines = Vec::new();
    for (i, (_, label, value)) in fields.iter().enumerate() {
        let is_focused = focused && i == focus_index;
        let displayed = if label.starts_with("Password") {
            "*".repeat(value.chars().count())
        } else {
            value.to_string()
        };

        let marker = if is_focused { "> " } else { "  " };
        let style = if is_focused {
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)
        } else {
            Style::default()
        };

        lines.push(Line::from(Span::styled(
            format!("{marker}{label}: {displayed}"),
            style,
        )));
    }

    let p = Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title(title));
    frame.render_widget(p, area);
}

fn render_profile(frame: &mut Frame, area: Rect, app: &App) {
    let mut lines = vec![Line::from("Press 'd' to detect this machine's CPU and GPUs.")];
    lines.push(Line::from(""));

    match &app.state.hardware_profile {
        Some(profile) => {
            lines.push(Line::from(format!("Integrated GPU: {:?}", profile.igpu)));
            lines.push(Line::from(format!("Discrete GPU(s): {:?}", profile.dgpus)));
            lines.push(Line::from(format!(
                "NVIDIA driver: {:?}",
                profile.nvidia_driver_choice
            )));
            lines.push(Line::from(""));
            lines.push(Line::from(format!(
                "Graphics packages to install: {}",
                profile.graphics_packages().join(", ")
            )));
        }
        None => lines.push(Line::from("No hardware profile detected yet.")),
    }

    let p = Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title("Hardware profile"));
    frame.render_widget(p, area);
}

fn render_disk(frame: &mut Frame, area: Rect, app: &App) {
    let mut lines = vec![
        Line::from("Press 'r' to (re)list disks. Selecting one WILL ERASE it on install."),
        Line::from(""),
    ];

    if app.disks.is_empty() {
        lines.push(Line::from("No disks listed yet."));
    } else {
        for (i, d) in app.disks.iter().enumerate() {
            let is_selected = i == app.disk_selected;
            let marker = if is_selected { "> " } else { "  " };
            let style = if is_selected {
                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)
            } else {
                Style::default()
            };
            lines.push(Line::from(Span::styled(format!("{marker}{}", d.label()), style)));
        }
    }

    if let Some(layout) = &app.state.disk_layout {
        lines.push(Line::from(""));
        lines.push(Line::from(Span::styled(
            format!("Selected: {}", layout.target_disk),
            Style::default().fg(Color::Green),
        )));
    }

    let p = Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title("Disk layout"));
    frame.render_widget(p, area);
}

fn render_install(frame: &mut Frame, area: Rect, app: &App) {
    let mut lines = vec![Line::from("Ready to install with the following configuration:")];
    lines.push(Line::from(""));
    lines.push(Line::from(format!(
        "  Username: {}",
        app.state.account.username.as_deref().unwrap_or("(unset)")
    )));
    lines.push(Line::from(format!(
        "  Hostname: {}",
        app.state.account.hostname.as_deref().unwrap_or("(unset)")
    )));
    lines.push(Line::from(format!(
        "  Locale: {}",
        app.state.system.locale.as_deref().unwrap_or("(unset)")
    )));
    lines.push(Line::from(format!(
        "  Target disk: {}",
        app.state
            .disk_layout
            .as_ref()
            .map(|d| d.target_disk.clone())
            .unwrap_or_else(|| "(unset)".to_string())
    )));

    let missing = app.state.missing_fields();
    if !missing.is_empty() {
        lines.push(Line::from(""));
        lines.push(Line::from(Span::styled(
            format!("Missing before install can run: {}", missing.join(", ")),
            Style::default().fg(Color::Red),
        )));
    }

    let p = Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title("Install"));
    frame.render_widget(p, area);
}

fn render_finalize(frame: &mut Frame, area: Rect) {
    let p = Paragraph::new("Done. Press Enter to exit.")
        .block(Block::default().borders(Borders::ALL).title("Finalization"));
    frame.render_widget(p, area);
}
