from pathlib import Path

from configs import ios_workflow, setup_local_app
from configs.swift_environment import swift_module_cache_environment


def test_module_cache_avoids_legacy_modules_and_reuses_current_location(tmp_path):
    build_dir = tmp_path / "build" / "swiftpm"
    legacy_module = build_dir / "module-cache" / "SwiftShims.pcm"
    legacy_module.parent.mkdir(parents=True)
    legacy_module.write_bytes(b"legacy module")

    environment = swift_module_cache_environment(build_dir)
    cache = Path(environment["CLANG_MODULE_CACHE_PATH"])

    assert cache.is_absolute()
    assert cache.is_dir()
    assert list(cache.iterdir()) == []
    current_module = cache / "SwiftShims.pcm"
    current_module.write_bytes(b"current module")

    assert swift_module_cache_environment(build_dir) == environment
    assert current_module.read_bytes() == b"current module"
    assert legacy_module.read_bytes() == b"legacy module"


def test_moving_checkout_selects_fresh_module_cache(tmp_path):
    checkout = tmp_path / "original"
    build_dir = checkout / "build" / "swiftpm"
    cache = Path(swift_module_cache_environment(build_dir)["CLANG_MODULE_CACHE_PATH"])
    (cache / "SwiftShims.pcm").write_bytes(b"module with original absolute paths")
    cache_relative_path = cache.relative_to(checkout)

    moved_checkout = checkout.rename(tmp_path / "renamed")
    moved_build_dir = moved_checkout / "build" / "swiftpm"
    moved_cache = Path(
        swift_module_cache_environment(moved_build_dir)["CLANG_MODULE_CACHE_PATH"]
    )

    assert list(moved_cache.iterdir()) == []
    assert moved_cache != moved_checkout / cache_relative_path
    assert (moved_checkout / cache_relative_path / "SwiftShims.pcm").is_file()


def test_setup_and_workflow_share_cache_and_preserve_inherited_environment(monkeypatch, tmp_path):
    monkeypatch.setattr(setup_local_app, "SWIFTPM_BUILD_DIR", tmp_path)
    monkeypatch.setattr(ios_workflow, "SWIFTPM_BUILD_DIR", tmp_path)
    monkeypatch.setenv("CLANG_MODULE_CACHE_PATH", str(tmp_path / "inherited-cache"))
    monkeypatch.setenv("SWIFT_ENVIRONMENT_TEST", "preserved")

    setup_environment = setup_local_app._swift_env()
    workflow_environment = ios_workflow._swift_env()

    assert (
        setup_environment["CLANG_MODULE_CACHE_PATH"]
        == workflow_environment["CLANG_MODULE_CACHE_PATH"]
    )
    assert setup_environment["CLANG_MODULE_CACHE_PATH"] != str(tmp_path / "inherited-cache")
    assert setup_environment["SWIFT_ENVIRONMENT_TEST"] == "preserved"


def test_swift_tests_use_workflow_module_cache(monkeypatch, tmp_path):
    monkeypatch.setattr(ios_workflow, "SWIFTPM_BUILD_DIR", tmp_path)
    monkeypatch.setattr(ios_workflow, "_ensure_local_app_config", lambda: None)
    commands = []
    monkeypatch.setattr(
        ios_workflow, "_run", lambda cmd, **kwargs: commands.append((cmd, kwargs))
    )

    ios_workflow._test_for_platform("logic", platform="mac")

    command, kwargs = commands[-1]
    assert command[:2] == ["swift", "test"]
    assert kwargs["env"] == ios_workflow._swift_env()
