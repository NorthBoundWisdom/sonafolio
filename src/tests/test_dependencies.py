from __future__ import annotations

from pathlib import Path
import re
import subprocess

import pytest

from configs import dependencies, qt_workflow

ROOT = Path(__file__).resolve().parents[2]


def _git(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(root), *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def _upstream(tmp_path: Path) -> tuple[Path, list[str]]:
    upstream = tmp_path / "upstream"
    upstream.mkdir()
    _git(upstream, "init", "--quiet")
    _git(upstream, "config", "uploadpack.allowReachableSHA1InWant", "true")
    commits = []
    for revision in ("one", "two"):
        (upstream / "CMakeLists.txt").write_text(f"# {revision}\n", encoding="utf-8")
        _git(upstream, "add", ".")
        _git(upstream, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
             "commit", "--quiet", "-m", revision)
        commits.append(_git(upstream, "rev-parse", "HEAD"))
    return upstream, commits


def _pin(tmp_path: Path, upstream: Path, commit: str) -> dependencies.PinnedDependency:
    return dependencies.PinnedDependency(
        name="GeoControls",
        remote=upstream.as_uri(),
        commit=commit,
        path=tmp_path / "build/dependencies/GeoControls",
    )


def test_prepare_fetches_missing_checkout_at_pinned_commit(tmp_path) -> None:
    upstream, commits = _upstream(tmp_path)
    root = dependencies.prepare(_pin(tmp_path, upstream, commits[0]))

    assert _git(root, "rev-parse", "HEAD") == commits[0]
    assert (root / "CMakeLists.txt").read_text(encoding="utf-8") == "# one\n"


def test_prepare_moves_clean_checkout_to_new_pin(tmp_path) -> None:
    upstream, commits = _upstream(tmp_path)
    dependencies.prepare(_pin(tmp_path, upstream, commits[0]))
    root = dependencies.prepare(_pin(tmp_path, upstream, commits[1]))

    assert _git(root, "rev-parse", "HEAD") == commits[1]


def test_prepare_refuses_to_replace_modified_checkout(tmp_path) -> None:
    upstream, commits = _upstream(tmp_path)
    root = dependencies.prepare(_pin(tmp_path, upstream, commits[0]))
    (root / "CMakeLists.txt").write_text("# local edit\n", encoding="utf-8")

    with pytest.raises(dependencies.DependencyError, match="local changes"):
        dependencies.prepare(_pin(tmp_path, upstream, commits[1]))
    assert (root / "CMakeLists.txt").read_text(encoding="utf-8") == "# local edit\n"


def test_prepare_refuses_non_git_directory(tmp_path) -> None:
    upstream, commits = _upstream(tmp_path)
    pin = _pin(tmp_path, upstream, commits[0])
    pin.path.mkdir(parents=True)

    with pytest.raises(dependencies.DependencyError, match="not a Git checkout"):
        dependencies.prepare(pin)


def test_custom_geocontrols_checkout_is_used_without_preparation(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("GEOCONTROLS_SOURCE_ROOT", str(tmp_path / "custom"))
    monkeypatch.setattr(dependencies, "prepare", lambda pin: pytest.fail("custom root was prepared"))

    root = qt_workflow._geocontrols_source_root(qt_workflow.parse_args(["config"]))

    assert root == (tmp_path / "custom").resolve()


def test_default_geocontrols_checkout_is_prepared(monkeypatch, tmp_path) -> None:
    monkeypatch.delenv("GEOCONTROLS_SOURCE_ROOT", raising=False)
    prepared = []
    monkeypatch.setattr(dependencies, "prepare", lambda pin: prepared.append(pin) or pin.path)

    root = qt_workflow._geocontrols_source_root(qt_workflow.parse_args(["config"]))

    assert root == ROOT / "build/dependencies/GeoControls"
    assert prepared[0].commit == dependencies.load_pin("GeoControls").commit


def test_release_workflow_checks_out_pinned_geocontrols_commit() -> None:
    pin = dependencies.load_pin("GeoControls")
    workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")

    assert re.search(rf"repository: NorthBoundWisdom/GeoControls\s+ref: {pin.commit}", workflow)
