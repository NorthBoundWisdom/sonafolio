"""Prepare pinned source dependencies under the ignored build directory."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import subprocess

REPO_ROOT = Path(__file__).resolve().parents[1]
PIN_FILE = REPO_ROOT / "configs" / "dependencies.json"


class DependencyError(RuntimeError):
    pass


@dataclass(frozen=True)
class PinnedDependency:
    name: str
    remote: str
    commit: str
    path: Path


def load_pin(name: str, *, pin_file: Path = PIN_FILE, repo_root: Path = REPO_ROOT) -> PinnedDependency:
    entry = json.loads(pin_file.read_text(encoding="utf-8"))[name]
    return PinnedDependency(
        name=name,
        remote=entry["remote"],
        commit=entry["commit"],
        path=(repo_root / entry["path"]).resolve(),
    )


def _git(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, text=True, check=False
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise DependencyError(f"git {' '.join(args)} failed in {root}: {detail}")
    return completed.stdout.strip()


def _fetch_and_checkout(pin: PinnedDependency) -> None:
    print(f"SonaFolio: fetching {pin.name} {pin.commit[:12]} from {pin.remote}", flush=True)
    _git(pin.path, "fetch", "--depth", "1", "origin", pin.commit)
    _git(pin.path, "checkout", "--quiet", "--detach", pin.commit)


def prepare(pin: PinnedDependency) -> Path:
    """Materialize the pinned commit, leaving modified checkouts untouched."""
    root = pin.path
    if not root.exists():
        root.mkdir(parents=True)
        _git(root, "init", "--quiet")
        _git(root, "remote", "add", "origin", pin.remote)
        _fetch_and_checkout(pin)
        return root
    if not (root / ".git").exists():
        raise DependencyError(
            f"{root} exists but is not a Git checkout. Remove it so {pin.name} can be prepared."
        )
    if _git(root, "rev-parse", "HEAD") == pin.commit:
        return root
    if _git(root, "status", "--porcelain", "--untracked-files=normal"):
        raise DependencyError(
            f"{pin.name} at {root} has local changes and is not at the pinned commit "
            f"{pin.commit}. Commit, stash, or remove them before configuring."
        )
    _git(root, "remote", "set-url", "origin", pin.remote)
    try:
        _git(root, "cat-file", "-e", f"{pin.commit}^{{commit}}")
        _git(root, "checkout", "--quiet", "--detach", pin.commit)
    except DependencyError:
        _fetch_and_checkout(pin)
    return root
