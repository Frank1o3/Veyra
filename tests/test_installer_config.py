from pathlib import Path
from unittest.mock import MagicMock

from veyra_installer import bootloader, shell, system
from veyra_installer.disk import Layout


def test_install_bootloader_writes_kernel_cmdline(monkeypatch, tmp_path: Path) -> None:
    mount = tmp_path / "mnt"
    mount.mkdir()
    monkeypatch.setattr(bootloader, "MOUNT", str(mount))
    monkeypatch.setattr(shell, "MOUNT", str(mount))

    mock_run = MagicMock()
    mock_chroot = MagicMock()
    monkeypatch.setattr(bootloader, "run", mock_run)
    monkeypatch.setattr(bootloader, "chroot", mock_chroot)

    layout = Layout(
        esp="/dev/sda1",
        swap="/dev/sda2",
        root="/dev/sda3",
        root_uuid="11111111-1111-1111-1111-111111111111",
        swap_uuid="22222222-2222-2222-2222-222222222222",
    )

    bootloader.install_bootloader("/dev/sda", layout)

    cmdline_file = mount / "etc/kernel/cmdline"
    assert cmdline_file.is_file()
    cmdline_content = cmdline_file.read_text()
    assert "root=UUID=11111111-1111-1111-1111-111111111111" in cmdline_content
    assert "resume=UUID=22222222-2222-2222-2222-222222222222" in cmdline_content


def test_install_dotfiles_stages_to_var_tmp(monkeypatch, tmp_path: Path) -> None:
    mount = tmp_path / "mnt"
    mount.mkdir()
    monkeypatch.setattr(system, "MOUNT", str(mount))
    monkeypatch.setattr(shell, "MOUNT", str(mount))

    dotfiles_src = tmp_path / "dotfiles"
    dotfiles_src.mkdir()
    (dotfiles_src / "setup.sh").write_text("#!/bin/sh\nexit 0\n")
    monkeypatch.setenv("VEYRA_DOTFILES_SOURCE", str(dotfiles_src))

    commands_run = []

    def fake_run(cmd, **kwargs):
        commands_run.append(list(cmd))
        if cmd[0] == "cp":
            dest = Path(cmd[3])
            dest.mkdir(parents=True, exist_ok=True)
            (dest / "setup.sh").write_text("#!/bin/sh\nexit 0\n")
        return 0

    chroot_calls = []

    def fake_chroot(*args, **kwargs):
        chroot_calls.append(list(args))
        return 0

    monkeypatch.setattr(system, "run", fake_run)
    monkeypatch.setattr(system, "chroot", fake_chroot)
    monkeypatch.setattr(system.branding, "install_fastfetch_config", MagicMock())

    cfg = {"username": "testuser", "xkb_layout": "us"}
    system.install_dotfiles(cfg)

    # Verify staged path is under /var/tmp and NOT /tmp
    assert chroot_calls[0] == ["/var/tmp/veyra-dotfiles/setup.sh", "--config-only", "--user", "testuser"]
    expected_staged = f"{mount}/var/tmp/veyra-dotfiles"
    assert any(expected_staged in str(arg) for cmd in commands_run for arg in cmd)
    unexpected_staged = f"{mount}/tmp/veyra-dotfiles"
    assert not any(unexpected_staged in str(arg) for cmd in commands_run for arg in cmd)
