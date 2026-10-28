"""Repository build metadata and plugin adapter without generated dependency locks."""

import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from configs import app_build, qt_workflow, source_root_workflow


@pytest.fixture
def app_root(tmp_path, monkeypatch):
    monkeypatch.delenv("ATOT_RELEASE_VERSION", raising=False)
    monkeypatch.delenv("XCODE_DEVELOPMENT_TEAM", raising=False)
    monkeypatch.delenv("MARKETING_VERSION", raising=False)
    monkeypatch.delenv("ARCHIVE_ID", raising=False)
    (tmp_path / "configs").mkdir()
    (tmp_path / "configs/app_build.json").write_text(json.dumps({
        "MARKETING_VERSION": "1.2.3", "ARCHIVE_ID": "4", "XCODE_DEVELOPMENT_TEAM": "",
    }), encoding="utf-8")
    return tmp_path


def test_app_settings_need_only_committed_metadata(app_root):
    assert app_build.load_app_build_settings(app_root)["MARKETING_VERSION"] == "1.2.3"
    (app_root / "build.local.json").write_text(
        '{"environment": {"ARCHIVE_ID": "5", "XCODE_DEVELOPMENT_TEAM": "ABCDEFGHIJ"}}', encoding="utf-8"
    )
    settings = app_build.load_app_build_settings(app_root)
    assert settings == {
        "MARKETING_VERSION": "1.2.3", "ARCHIVE_ID": "5", "XCODE_DEVELOPMENT_TEAM": "ABCDEFGHIJ",
    }


@pytest.mark.parametrize("override", [
    {"ARCHIVE_ID": "0"}, {"MARKETING_VERSION": ""}, {"XCODE_DEVELOPMENT_TEAM": "invalid"},
    {"ARCHIVE_ID": 3}, {"MARKETING_VERSION": "1.0\nother"},
])
def test_invalid_app_overrides_fail_explicitly(app_root, override):
    (app_root / "build.local.json").write_text(json.dumps({"environment": override}), encoding="utf-8")
    with pytest.raises(ValueError):
        app_build.load_app_build_settings(app_root)


def test_missing_app_metadata_fails_explicitly(tmp_path):
    with pytest.raises(ValueError, match="Unable to read"):
        app_build.load_app_build_settings(tmp_path)


def test_release_environment_overrides_version_and_local_signing(app_root, monkeypatch):
    monkeypatch.setenv("ATOT_RELEASE_VERSION", "2.3.4")
    monkeypatch.setenv("XCODE_DEVELOPMENT_TEAM", "ABCDEFGHIJ")
    assert app_build.load_app_build_settings(app_root) == {
        "MARKETING_VERSION": "2.3.4", "ARCHIVE_ID": "1", "XCODE_DEVELOPMENT_TEAM": "ABCDEFGHIJ",
    }


@pytest.mark.parametrize("action", ["--init", "--update"])
def test_plugin_setup_uses_host_commands(action, monkeypatch):
    calls = []
    monkeypatch.setattr(source_root_workflow, "setup_local_app_main", lambda: calls.append(1) or 0)
    assert source_root_workflow.main([action, "--quiet"]) == 0
    assert calls == [1]


def test_plugin_clean_dry_run_preserves_outputs_and_local_config(app_root, monkeypatch):
    monkeypatch.setattr(source_root_workflow, "REPO_ROOT", app_root)
    output = app_root / "build/Audio2TextQt/output.txt"
    output.parent.mkdir(parents=True)
    output.write_text("keep until explicit cleanup")
    assert source_root_workflow.main(["--cleanbuild", "--dry-run"]) == 0
    assert output.is_file()
    assert source_root_workflow.main(["--cleanbuild"]) == 0
    assert not output.exists()
    assert (app_root / "configs/app_build.json").is_file()


@pytest.mark.skipif(not shutil.which("cmake"), reason="CMake unavailable")
@pytest.mark.parametrize("source_option", ["cache", "environment"])
def test_cmake_accepts_prepared_geocontrols_without_network(tmp_path, source_option):
    source, project, build = (tmp_path / name for name in ("controls", "project", "build"))
    source.mkdir()
    project.mkdir()
    (source / "CMakeLists.txt").write_text(
        "add_library(GeoControlsControls INTERFACE)\nadd_library(GeoControlsAppShell INTERFACE)\n"
    )
    for name in ("Controls", "AppShell"):
        (source / name).mkdir()
        (source / name / "CMakeLists.txt").write_text("# Fixture\n")
    (source / "LICENSE").write_text("MIT License\n")
    module = Path(__file__).resolve().parents[2] / "qt/Audio2TextQt/cmake/GeoControls.cmake"
    (project / "CMakeLists.txt").write_text(
        f'cmake_minimum_required(VERSION 3.24)\nproject(Fixture NONE)\ninclude("{module.as_posix()}")\n'
    )
    environment = dict(os.environ)
    environment.pop("GEOCONTROLS_SOURCE_ROOT", None)
    command = ["cmake", "-S", str(project), "-B", str(build)]
    if source_option == "cache":
        command.append(f"-DGEOCONTROLS_SOURCE_ROOT={source}")
    else:
        environment["GEOCONTROLS_SOURCE_ROOT"] = str(source)
    result = subprocess.run(command, env=environment, text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert Path(qt_workflow._cache_value(build, "SONAFOLIO_GEOCONTROLS_SOURCE_ROOT")).resolve() == source.resolve()


@pytest.mark.skipif(not shutil.which("cmake"), reason="CMake unavailable")
@pytest.mark.parametrize("missing", ["unset", "absent-directory"])
def test_cmake_missing_dependency_fails_without_preparing_sources(tmp_path, monkeypatch, missing):
    monkeypatch.delenv("GEOCONTROLS_SOURCE_ROOT", raising=False)
    project, build = tmp_path / "project", tmp_path / "build"
    project.mkdir()
    module = Path(__file__).resolve().parents[2] / "qt/Audio2TextQt/cmake/GeoControls.cmake"
    (project / "CMakeLists.txt").write_text(
        f'cmake_minimum_required(VERSION 3.24)\nproject(Fixture NONE)\ninclude("{module.as_posix()}")\n'
    )
    command = ["cmake", "-S", str(project), "-B", str(build)]
    if missing != "unset":
        command.append(f"-DGEOCONTROLS_SOURCE_ROOT={tmp_path / 'absent'}")
    result = subprocess.run(command, text=True, capture_output=True, timeout=15)
    assert result.returncode != 0
    assert "python3 configs/qt_workflow.py config" in " ".join(result.stderr.split())
    assert not (build / "_deps").exists()
    assert not (tmp_path / "absent").exists()


def test_package_attributes_actual_clean_geocontrols_revision(tmp_path):
    source, build = tmp_path / "controls", tmp_path / "build"
    source.mkdir()
    build.mkdir()

    def git(*args):
        return subprocess.run(
            ["git", "-C", str(source), *args], text=True, check=True, capture_output=True
        ).stdout.strip()

    git("init")
    (source / "LICENSE").write_text("MIT License\n")
    git("add", ".")
    git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
        "-c", "commit.gpgsign=false", "commit", "-m", "Fixture")
    revision = git("rev-parse", "HEAD")
    (build / "CMakeCache.txt").write_text(f"SONAFOLIO_GEOCONTROLS_SOURCE_ROOT:INTERNAL={source}\n")
    assert qt_workflow._geocontrols_release_source(build) == (source.resolve(), revision)
    (source / "LICENSE").write_text("changed source")
    with pytest.raises(ValueError, match="must be clean"):
        qt_workflow._geocontrols_release_source(build)
