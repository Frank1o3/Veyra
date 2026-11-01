from pathlib import Path

from veyra_installer import packages


def test_cached_archives_are_sorted_for_offline_install(tmp_path: Path) -> None:
    (tmp_path / "b.pkg.tar.zst").write_text("b")
    (tmp_path / "a.pkg.tar.zst").write_text("a")
    (tmp_path / "c.pkg.tar.zst").write_text("c")

    archives = packages.cached_package_archives(tmp_path)

    assert archives == [
        tmp_path / "a.pkg.tar.zst",
        tmp_path / "b.pkg.tar.zst",
        tmp_path / "c.pkg.tar.zst",
    ]
