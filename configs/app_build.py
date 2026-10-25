"""Shared application build metadata, independent of dependency management."""

from __future__ import annotations

import json
from pathlib import Path
import re

from configs.build_environment import load_build_environment

REPO_ROOT = Path(__file__).resolve().parents[1]
SETTING_KEYS = {"MARKETING_VERSION", "ARCHIVE_ID", "XCODE_DEVELOPMENT_TEAM"}


def _read_settings(path: Path) -> dict[str, str]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Unable to read application build settings from {path}: {error}") from error
    if not isinstance(value, dict) or set(value) - SETTING_KEYS:
        raise ValueError(f"{path.name} must be an object containing only application build settings.")
    if any(not isinstance(item, str) or "\n" in item or "\r" in item for item in value.values()):
        raise ValueError(f"{path.name} build settings must be single-line strings.")
    return {key: item.strip() for key, item in value.items()}


def load_app_build_settings(repo_root: Path | None = None) -> dict[str, str]:
    root = repo_root if repo_root is not None else REPO_ROOT
    settings = _read_settings(root / "configs/app_build.json")
    environment = load_build_environment(root)
    for key in SETTING_KEYS:
        if key in environment:
            settings[key] = environment[key].strip()
    release = environment.get("ATOT_RELEASE_VERSION", "")
    if release:
        if not re.fullmatch(r"\d+\.\d+\.\d+", release):
            raise ValueError("ATOT_RELEASE_VERSION must be a numeric major.minor.patch version.")
        settings.update(MARKETING_VERSION=release, ARCHIVE_ID="1")
    version = settings.get("MARKETING_VERSION", "")
    archive = settings.get("ARCHIVE_ID", "")
    team = settings.setdefault("XCODE_DEVELOPMENT_TEAM", "")
    if not re.fullmatch(r"\d+(?:\.\d+){0,3}(?:[A-Za-z0-9.+-]*)?", version):
        raise ValueError("Application build settings require a valid MARKETING_VERSION.")
    if not archive.isascii() or not archive.isdigit() or int(archive) <= 0:
        raise ValueError("Application build settings require a positive numeric ARCHIVE_ID.")
    if team and not re.fullmatch(r"[A-Za-z0-9]{10}", team):
        raise ValueError("XCODE_DEVELOPMENT_TEAM must be empty or a 10-character team identifier.")
    return settings
