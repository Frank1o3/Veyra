mod bootloader;
mod disk;
mod hardware;
mod install;
mod postinstall;
mod profiles;
mod state;
mod ui;

fn main() -> std::io::Result<()> {
    let terminal = ratatui::init();
    let result = ui::run(terminal);
    ratatui::restore();
    result
}
