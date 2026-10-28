"""Keep Swift's Clang module cache specific to its absolute location."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path


def swift_module_cache_environment(build_dir: Path) -> dict[str, str]:
    cache_root = (build_dir / "module-cache").resolve()
    # Precompiled modules retain absolute paths and cannot move with a checkout.
    location = hashlib.sha256(os.fsencode(cache_root)).hexdigest()[:16]
    module_cache = cache_root / location
    module_cache.mkdir(parents=True, exist_ok=True)
    return {"CLANG_MODULE_CACHE_PATH": str(module_cache)}
