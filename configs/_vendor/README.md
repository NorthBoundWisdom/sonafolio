# Vendored FreeCM command validator

This directory contains only the FreeCM command-manifest validator and its JSONC
stripping helpers. The snapshot is from
FreeCM 0.1.156, commit `52a9a57fbe959cbe57e91b0d1473c82eff0ba2af`.
See `UPSTREAM.json` for upstream paths, original SHA-256 hashes, and local changes;
`LICENSE` preserves the upstream MIT notice.

Imports use the private `configs._vendor` namespace. No FreeCM checkout or installed
Python package is needed. Dependency resolution, source-root locks, adapters and the
extension are excluded. These helpers stay outside the CLI wheel and sdist.

`configs/freecm.commands.jsonc` retains Config/Build/Run/Test/Package actions.
`configs/source_root_workflow.py` is a thin plugin adapter for local setup and build
cleanup. Application metadata uses `configs/app_build.json`; local environments use
ignored root `build.local.json`. Qt only consumes prepared local dependency sources.
This repository does not use FreeCM dependency lock modes or automatic CMake downloads.
