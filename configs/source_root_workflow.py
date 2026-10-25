#!/usr/bin/env python3
# Usage: python3 configs/source_root_workflow.py --init|--update
"""Optional FreeCM plugin adapter for the repository's own setup commands."""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from configs.setup_local_app import main as setup_local_app_main  # noqa: E402

# Explicit targets exclude runtime data, SDKs, and generated Xcode user state.
CLEAN_TARGETS = ("Audio2TextQt", "ci-qt", "ci-qt-stage", "app", "package", "package-staging", "swiftpm")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--init", action="store_true", help="Prepare the local application runtime.")
    action.add_argument("--update", action="store_true", help="Refresh the local application setup.")
    action.add_argument("--cleanbuild", action="store_true", help="Remove native client build outputs.")
    parser.add_argument("--quiet", action="store_true", help="Accepted for plugin invocations.")
    parser.add_argument("--dry-run", action="store_true", help="Preview --cleanbuild without deleting files.")
    args = parser.parse_args(argv)
    if args.dry_run and not args.cleanbuild:
        parser.error("--dry-run requires --cleanbuild")
    if not args.cleanbuild:
        return setup_local_app_main()
    build = REPO_ROOT / "build"
    if build.is_symlink():
        raise ValueError("Refusing to clean a symlinked build directory.")
    for name in CLEAN_TARGETS:
        path = build / name
        if not path.exists() and not path.is_symlink():
            continue
        print(f"{'Would remove' if args.dry_run else 'Removing'} build/{name}")
        if not args.dry_run:
            if path.is_symlink() or path.is_file():
                path.unlink()
            else:
                shutil.rmtree(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
