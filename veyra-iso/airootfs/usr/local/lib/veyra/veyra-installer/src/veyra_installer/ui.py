"""Console output and interactive prompts."""
from __future__ import annotations

import re
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.prompt import Confirm, Prompt

from .config import (
    DEFAULT_LOCALE,
    DEFAULT_TIMEZONE,
    LOG_FILE,
    XKB_TO_CONSOLE,
)
from .hardware import Hardware

console = Console()


def step(title: str) -> None:
    console.print()
    console.rule(f"[bold cyan]{title}")


def banner() -> None:
    text = "VEYRA OS"
    try:
        import pyfiglet  # optional

        text = pyfiglet.figlet_format("VEYRA", font="slant")
    except Exception:
        pass
    console.print(Panel.fit(f"[bold cyan]{text}[/]\n[dim]Guided installer[/]", border_style="cyan"))
    console.print(f"[dim]Output is mirrored to {LOG_FILE}[/]")


def ask_validated(prompt: str, pattern: str, error: str, default: str | None = None) -> str:
    while True:
        value = Prompt.ask(prompt, default=default) if default else Prompt.ask(prompt)
        if re.fullmatch(pattern, value):
            return value
        console.print(f"[red]{error}[/]")


def ask_locale() -> str:
    supported = Path("/usr/share/i18n/SUPPORTED")
    lines = set(supported.read_text().splitlines()) if supported.exists() else set()
    while True:
        loc = ask_validated("Locale", r"[A-Za-z0-9_.@-]+", "Invalid locale syntax.", DEFAULT_LOCALE)
        if not lines or f"{loc} UTF-8" in lines:
            return loc
        console.print(f"[red]Locale is not available: {loc}[/]")


def ask_timezone() -> str:
    while True:
        tz = ask_validated(
            "Timezone",
            r"[A-Za-z0-9_+.-]+(/[A-Za-z0-9_+.-]+)*",
            "Invalid timezone syntax.",
            DEFAULT_TIMEZONE,
        )
        if Path(f"/usr/share/zoneinfo/{tz}").is_file():
            return tz
        console.print(f"[red]Unknown timezone: {tz}[/]")


def ask_password() -> str:
    while True:
        pw = Prompt.ask("User password", password=True)
        if pw and pw == Prompt.ask("Repeat password", password=True):
            return pw
        console.print("[red]Passwords are empty or do not match.[/]")


def _console_keymaps() -> set[str]:
    names = set()
    for p in Path("/usr/share/kbd/keymaps").rglob("*.map*"):
        names.add(p.name.split(".map")[0])
    return names


def ask_keyboard() -> tuple[str, str]:
    """Returns (xkb_layout, console_keymap)."""
    maps = _console_keymaps()
    while True:
        layout = (
            Prompt.ask("Keyboard layout [dim](us, latam, es, gb, de, fr, br, ...)[/]", default="us")
            .strip()
            .lower()
        )
        if layout in XKB_TO_CONSOLE:
            xkb, cmap = layout, XKB_TO_CONSOLE[layout]
        elif layout in maps:
            xkb, cmap = layout, layout
            console.print(
                f"[yellow]Using '{layout}' for both console and desktop; "
                "adjust the desktop layout later if it differs.[/]"
            )
        else:
            console.print(f"[red]Unknown layout '{layout}'.[/]")
            continue
        if maps and cmap not in maps:
            console.print(f"[red]Console keymap '{cmap}' is not available in this image.[/]")
            continue
        return xkb, cmap


def ask_v3_kernel(hw: Hardware) -> bool:
    import time

    if not hw.v3:
        return False
    if not Confirm.ask("This CPU supports x86-64-v3. Install the optimized v3 kernel?", default=False):
        return False
    console.print(
        Panel(
            "The v3 kernel will NOT boot on CPUs lacking x86-64-v3\n"
            "(AVX2, BMI1/2, FMA, MOVBE, LZCNT, F16C, ...).\n"
            "If this disk is ever moved to an older machine, it will not start.",
            title="Warning",
            border_style="red",
        )
    )
    time.sleep(8)
    return Confirm.ask("Are you sure you want the v3 kernel?", default=False)