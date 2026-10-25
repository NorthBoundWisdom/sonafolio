"""Local environment loading and command boundaries without downloads or shell evaluation."""

import json
import os
from pathlib import Path
import shutil

import pytest

from configs import app_build, build_environment, ci_release, ios_workflow, qt_workflow, setup_local_app
from configs.build_environment import (
    ensure_local_build_environment, load_build_environment, use_build_environment,
)
from scripts.check_public_paths import find_private_path_hits


def write_config(root, payload):
    (root / "build.local.json").write_text(json.dumps(payload), encoding="utf-8")


def copy_example(root):
    destination = root / "configs/build.local.example.json"
    destination.parent.mkdir(exist_ok=True)
    shutil.copy2(Path(__file__).resolve().parents[2] / "configs/build.local.example.json", destination)
    return destination


def test_initial_configuration_copies_valid_example_without_overwriting_local_settings(tmp_path):
    example = copy_example(tmp_path)
    assert ensure_local_build_environment(tmp_path) is True
    local = tmp_path / "build.local.json"
    assert local.read_bytes() == example.read_bytes()
    environment = load_build_environment(tmp_path, environ={})
    assert environment["GEOCONTROLS_SOURCE_ROOT"] == ""
    write_config(tmp_path, {"environment": {"CUSTOM_LOCAL": "keep"}})
    original = local.read_bytes()
    example.write_text('{"environment": {"CUSTOM_LOCAL": "changed"}}')
    assert ensure_local_build_environment(tmp_path) is False
    assert local.read_bytes() == original


def test_configuration_without_template_fails_before_creating_local_file(tmp_path):
    with pytest.raises(ValueError, match="Unable to read configs/build.local.example.json"):
        ensure_local_build_environment(tmp_path)
    assert not (tmp_path / "build.local.json").exists()


def test_setup_creates_local_environment_before_running_setup(tmp_path, monkeypatch):
    copy_example(tmp_path)
    monkeypatch.setattr(setup_local_app, "REPO_ROOT", tmp_path)
    calls = []
    monkeypatch.setattr(setup_local_app, "_main", lambda: calls.append((tmp_path / "build.local.json").is_file()) or 0)
    assert setup_local_app.main() == 0
    assert calls == [True]


def test_qt_config_creates_local_environment_but_help_and_build_do_not(tmp_path, monkeypatch):
    copy_example(tmp_path)
    monkeypatch.setattr(qt_workflow, "REPO_ROOT", tmp_path)
    for key, value in {
        "DEFAULT_BUILD_DIR": "build/Audio2TextQt",
        "DEFAULT_PACKAGE_DIR": "build/package",
        "DEFAULT_PACKAGE_STAGING_DIR": "build/package-staging",
    }.items():
        monkeypatch.setattr(qt_workflow, key, tmp_path / value)
    with pytest.raises(SystemExit) as result:
        qt_workflow.main(["config", "--help"])
    assert result.value.code == 0
    assert not (tmp_path / "build.local.json").exists()
    monkeypatch.setattr(qt_workflow, "_build", lambda *args, **kwargs: None)
    assert qt_workflow.main(["build"]) == 0
    assert not (tmp_path / "build.local.json").exists()
    calls = []
    monkeypatch.setattr(qt_workflow, "_configure", lambda *args: calls.append((tmp_path / "build.local.json").is_file()))
    assert qt_workflow.main(["config"]) == 0
    assert calls == [True]


def test_absent_local_file_preserves_environment_without_generating_files(tmp_path):
    inherited = {"PATH": "existing", "SDK": "external"}
    assert load_build_environment(tmp_path, environ=inherited) == inherited
    assert list(tmp_path.iterdir()) == []


def test_expansion_paths_and_explicit_environment_precedence(tmp_path):
    write_config(tmp_path, {
        "environment": {
            "SDK": "${REPO_ROOT}/sdk", "NESTED": "$SDK/lib", "FROM_HOME": "%HOME%/tools",
            "OVERRIDE": "file", "LITERAL": "$(touch should-not-run)",
        },
        "path": ["tools/bin", "$SDK/bin", "tools/bin"],
    })
    environment = load_build_environment(tmp_path, environ={
        "HOME": str(tmp_path / "home"), "OVERRIDE": "caller", "PATH": "existing",
    })
    assert environment["NESTED"] == str(tmp_path / "sdk") + "/lib"
    assert environment["FROM_HOME"] == str(tmp_path / "home") + "/tools"
    assert environment["OVERRIDE"] == "caller"
    assert environment["LITERAL"] == "$(touch should-not-run)"
    assert environment["PATH"].split(os.pathsep) == [
        str(tmp_path / "tools/bin"), str(tmp_path / "sdk/bin"), "existing",
    ]
    assert not (tmp_path / "should-not-run").exists()


@pytest.mark.parametrize("payload", [
    {"environment": {"VALUE": 1}}, {"environment": {"BAD-NAME": "value"}},
    {"environment": {"PATH": "value"}}, {"environment": {"VALUE": "a\nb"}},
    {"environment": {"VALUE": "$UNDEFINED"}},
    {"environment": {"ONE": "$TWO", "TWO": "$ONE"}},
    {"path": "invalid"}, {"path": [""]}, {"dependencies": {}},
])
def test_invalid_local_environment_fails_explicitly(tmp_path, payload):
    write_config(tmp_path, payload)
    with pytest.raises(ValueError):
        load_build_environment(tmp_path, environ={})


def test_nested_command_environment_is_restored_after_failure(tmp_path, monkeypatch):
    monkeypatch.delenv("BUILD_ENV_TEST", raising=False)
    write_config(tmp_path, {"environment": {"BUILD_ENV_TEST": "local"}, "path": ["tools"]})
    original = dict(os.environ)
    with pytest.raises(RuntimeError, match="fixture"):
        with use_build_environment(tmp_path):
            first_path = os.environ["PATH"]
            with use_build_environment(tmp_path):
                assert os.environ["PATH"] == first_path
                assert os.environ["BUILD_ENV_TEST"] == "local"
                raise RuntimeError("fixture")
    assert dict(os.environ) == original


def test_windows_environment_precedence_is_case_insensitive(tmp_path, monkeypatch):
    monkeypatch.setattr(build_environment, "WINDOWS_ENVIRONMENT", True)
    write_config(tmp_path, {"environment": {"QT6_DIR": "local", "CHILD": "$qt6_dir/lib"}})
    environment = load_build_environment(tmp_path, environ={"Qt6_DIR": "caller"})
    assert environment["QT6_DIR"] == "caller"
    assert environment["CHILD"] == "caller/lib"


@pytest.mark.parametrize("module", [qt_workflow, ios_workflow, setup_local_app, ci_release])
def test_all_build_entrypoints_load_the_same_root_environment(tmp_path, monkeypatch, module):
    monkeypatch.delenv("BUILD_ENV_TEST", raising=False)
    write_config(tmp_path, {"environment": {"BUILD_ENV_TEST": "local"}})
    monkeypatch.setattr(module, "ROOT" if module is ci_release else "REPO_ROOT", tmp_path)
    values = []
    monkeypatch.setattr(module, "_main", lambda *args: values.append(os.environ["BUILD_ENV_TEST"]) or 0)
    module.main()
    assert values == ["local"]
    assert "BUILD_ENV_TEST" not in os.environ


@pytest.mark.parametrize("explicit_source", [False, True])
def test_qt_config_uses_local_sdk_and_source_without_a_shell(tmp_path, monkeypatch, explicit_source):
    for key in ("GEOCONTROLS_SOURCE_ROOT", "AUDIO2TEXTQT_QT_PREFIX"):
        monkeypatch.delenv(key, raising=False)
    sdk = tmp_path / "Qt"
    sdk_config = sdk / "lib/cmake/Qt6/Qt6Config.cmake"
    sdk_config.parent.mkdir(parents=True)
    sdk_config.write_text("")
    monkeypatch.setattr(qt_workflow, "_looks_like_qt_prefix", lambda path: path == sdk)
    monkeypatch.setattr(qt_workflow, "REPO_ROOT", tmp_path)
    for key, value in {
        "DEFAULT_BUILD_DIR": "build/Audio2TextQt",
        "DEFAULT_PACKAGE_DIR": "build/package",
        "DEFAULT_PACKAGE_STAGING_DIR": "build/package-staging",
    }.items():
        monkeypatch.setattr(qt_workflow, key, tmp_path / value)
    write_config(tmp_path, {"environment": {
        "GEOCONTROLS_SOURCE_ROOT": "${REPO_ROOT}/controls",
        "AUDIO2TEXTQT_QT_PREFIX": "${REPO_ROOT}/Qt",
    }})
    commands = []
    monkeypatch.setattr(qt_workflow, "_run", commands.append)
    arguments = ["config"]
    if explicit_source:
        arguments.extend(["--geocontrols-source", "other-controls"])
    assert qt_workflow.main(arguments) == 0
    source = tmp_path / ("other-controls" if explicit_source else "controls")
    assert f"-DGEOCONTROLS_SOURCE_ROOT={source}" in commands[0]
    assert f"-DCMAKE_PREFIX_PATH={sdk}" in commands[0]


def test_local_environment_is_rejected_as_public_source(tmp_path):
    write_config(tmp_path, {"environment": {"ARCHIVE_ID": "2"}})
    hits = find_private_path_hits([tmp_path / "build.local.json"], root=tmp_path)
    assert len(hits) == 1
    assert hits[0].label == "local secret config file"


def test_app_metadata_reads_local_environment_before_project_generation(tmp_path, monkeypatch):
    monkeypatch.delenv("ARCHIVE_ID", raising=False)
    monkeypatch.delenv("ATOT_RELEASE_VERSION", raising=False)
    (tmp_path / "configs").mkdir()
    (tmp_path / "configs/app_build.json").write_text('{"MARKETING_VERSION":"1.2.3","ARCHIVE_ID":"1"}')
    write_config(tmp_path, {"environment": {"ARCHIVE_ID": "9"}})
    assert app_build.load_app_build_settings(tmp_path)["ARCHIVE_ID"] == "9"
