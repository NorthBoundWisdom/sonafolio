# SonaFolio Agent Guide

## Build Configuration and FreeCM Plugin

- FreeCM is not a submodule or external build dependency. Only its plugin command
  validator is vendored under `configs/_vendor/`, with provenance and the MIT license.
  Do not restore automatic FreeCM checkout or refresh behavior.
- Preserve optional FreeCM Config/Build/Run/Test/Package commands in
  `configs/freecm.commands.jsonc`. `configs/source_root_workflow.py` is only the
  plugin's setup/cleanup adapter; it does not manage dependency locks or modes.
- GeoControls is pinned by remote and commit in `configs/dependencies.json`. Qt Config
  (`configs/qt_workflow.py config`) fetches that commit into ignored
  `build/dependencies/GeoControls` and refuses to replace a modified checkout; Build consumes
  the configured source. A `GEOCONTROLS_SOURCE_ROOT` or `--geocontrols-source` pointing
  elsewhere is used as-is. CMake itself never downloads. Keep the release workflow's
  GeoControls checkout ref equal to the pin.
- Application version defaults use `configs/app_build.json`. Root `build.local.json`
  is ignored and holds machine-local environment variables and PATH entries, including
  SDK/dependency paths and signing/version overrides. All build entrypoints load it
  through `configs/build_environment.py`. The public `configs/build.local.example.json`
  is copied only when the local file is missing during setup or Qt Config; never overwrite
  existing local settings. Do not recreate FreeCM source-root locks or dependency modes.
- Validate plugin commands with `python3 configs/validate_repo_commands.py .`.

This repository is public. Keep documentation, defaults, tests, and skills free of private absolute
paths, local usernames, machine-specific assumptions, and episode-specific tuning.

## Project Contract

- SonaFolio is a local Chinese podcast transcription CLI. The stable production path is
  macOS/Apple Silicon with MLX Whisper; Windows ASR uses the CLI with faster-whisper/CUDA. Qt client installers are available on macOS,
  Windows and Linux; iOS is a library reader. Linux ASR is not a stable supported backend.
- The stable production path is `atot exec transcribe` / `atot exec import` with the
  `large-v3-turbo` model alias. Old top-level command aliases such as `atot transcribe` and
  `atot import-xiaoyuzhou` are removed in CLI v2.
- Local runtime data lives under `~/Documents/SpeechToTextData/` by default and must stay out of git.
- `~/Documents/SpeechToTextData/model/` is the only local model storage location. `Downloads/` is
  temporary reference source and can be deleted without changing model resolution.
- Generated transcripts, model weights, downloaded audio, caches, and local reference checkouts are
  not source files.

## Development Commands

```bash
python3 configs/setup_local_app.py
~/Documents/SpeechToTextData/env/bin/atot doctor
~/Documents/SpeechToTextData/env/bin/python -m pytest
```

Useful focused checks:

```bash
~/Documents/SpeechToTextData/env/bin/python -m ruff check .
~/Documents/SpeechToTextData/env/bin/python src/scripts/check_public_paths.py
~/Documents/SpeechToTextData/env/bin/python src/scripts/validate_model_inventory.py
~/Documents/SpeechToTextData/env/bin/python src/scripts/validate_library.py Audio2TextLibrary
~/Documents/SpeechToTextData/env/bin/python -m pytest src/tests/test_xiaoyuzhou.py
~/Documents/SpeechToTextData/env/bin/python -m pytest src/tests/test_asr_candidate_presets.py src/tests/test_asr_candidate_readiness.py
~/Documents/SpeechToTextData/env/bin/python src/scripts/validate_run_json.py src/tests/fixtures/run.sample.json
```

Windows pytest discovery:

```powershell
where python
py -0p
python -m pip show pytest
python -c "import sys, pytest; print(sys.executable); print(pytest.__file__)"
python -m pytest
```

On Windows, prefer `python -m pytest` over invoking `pytest.exe` directly. A user-level
`pip install --user pytest` may place `pytest.exe` in a Scripts directory that is not on PATH, while
the module form still uses the pytest installed for the selected Python interpreter.

## Code Rules

- SwiftUI control geometry, colors, interaction styles, and reusable primitives live in
  `app/Sources/Audio2TextApp/AppControls.swift`, which is shared with iOS. Panels use the
  shared controls and semantic size/variant options instead of defining local control styles.
  Keep touch targets and desktop sizes in that shared layer. Qt controls use GeoControls.
- Do not develop on branches other than `main` unless the developer explicitly confirms
  branch-based work for the task. Without that confirmation, keep all development, commits, and
  pushes on `main`.
- Keep CLI behavior backward-compatible unless the user explicitly asks for a breaking change.
- Current product policy: do not add failure-compatibility or silent fallback behavior for summary,
  title, cloud, or local post-processing flows unless the user explicitly asks for it.
- When a required step fails, prefer surfacing the failure clearly over producing partial or heuristic
  replacement outputs.
- Remove obsolete compatibility code when the product policy has moved on and the user has asked to
  stop carrying it.
- Prefer shared rules in `src/atot/data/topic_rules.json` and `src/atot/data/review_rules.json`
  over hard-coded episode fixes.
- Keep backend-specific code behind `src/atot/backends/` or explicit candidate scripts.
- Keep reusable candidate comparison logic under `src/atot/candidate/`; `src/scripts/` should stay
  thin entrypoints.
- Do not promote a new ASR backend unless it passes the same candidate gate and semantic review.
- Use relative paths in examples. Use environment variables for user-specific directories.
- Keep deterministic corrections narrow, auditable, and recorded in `corrections.json`.

## Documentation Rules

- `README.md` is the public quick-start and stable CLI reference.
- `doc/README.md` is the documentation map.
- Create or keep root `TODO.md` only while concrete unfinished work exists; remove completed items
  instead of retaining an empty backlog. Completed roadmap evidence belongs in
  `doc/ROADMAP_STATUS.md`.
- `doc/BACKEND_RESEARCH.md` tracks backend research and should not become setup documentation.
- Experiment notes under `doc/experiments/` are historical records; update summaries instead of
  rewriting measured results.
- `.codex/skills/*/SKILL.md` must match the CLI behavior and public-path policy.

## Model Path Policy

The default model alias is `large-v3-turbo`, backed by
`mlx-community/whisper-large-v3-turbo`. Local model files should be placed under the data-root
`model/` directory, for example:

```text
~/Documents/SpeechToTextData/model/whisper-large-v3-turbo/
```

Candidate presets must also resolve model files under the data-root `model/`; do not add committed
absolute paths or `Downloads/` model references.

Agents must not download model files automatically. When a required model is missing, provide the
official download links and exact target files, then stop and ask the developer to download or place
the files under the data-root `model/` directory.

Model aliases, local paths, required files, and manual download URLs live in
`src/atot/data/model_inventory.json`. Update that inventory first, then update README if the
validated table changes.

## Windows CLI Notes

- Keep Windows ASR and setup independent of Swift, Xcode, or the macOS App build. The Qt client
  invokes the separately configured CLI; its installer does not bundle the ASR environment.
- Users may download faster-whisper model files into an arbitrary temporary download directory.
  Agents should move only clearly matching model files into the data-root `model/` directory and
  never commit those files.
- Use vcpkg-discovered tools such as `ffmpeg.exe` and `ffprobe.exe` through environment/PATH setup or
  runtime discovery. Do not commit local vcpkg roots or absolute machine paths.
- Set `VCPKG_ROOT` to the local vcpkg installation, and expose FFmpeg through PATH
  or `AUDIO2TEXTQT_FFMPEG_DIR` in ignored `build.local.json`. FreeCM commands load the
  same local environment; SDK paths must not be committed as application configuration.
- Keep Windows backend code behind `src/atot/backends/` and Windows runtime checks in small,
  testable modules.
- Prefer CUDA 13 when the installed CTranslate2 wheel can actually use it. If CTranslate2 reports
  missing CUDA 12 DLLs such as `cublas64_12.dll`, surface that compatibility issue clearly.
- Prefer explicit failures for missing CUDA, cuDNN, faster-whisper, ffmpeg, or model files. Do not
  add silent CPU or heuristic fallbacks unless the user asks for them. CPU is an explicit opt-in via
  `ATOT_FASTER_WHISPER_DEVICE=cpu`.

## Summary Files

`output/summary.md` is produced by the Codex Xiaoyuzhou import skill with the agent model. It is not
generated by the local ASR pipeline and should not be wired to a local model by default.

`atot mcp` also accepts summaries authored by the connected agent. Prefer its versioned library
read/write tools when available: read the complete transcript and QA, then publish through
`write_summary` with the current document hashes. Do not call a cloud API as part of this agent
summary path. Replacing a nonempty summary requires an explicit regeneration request.

## Public Website

- `website/` contains the SonaFolio product site and searchable user handbook, published through
  GitHub Pages. Keep platform, signing and download claims aligned with actual release workflows.
- Run a strict MkDocs build and `python configs/check_docs.py` when maintaining website/docs links.
- Use SonaFolio in product prose. Preserve only the compatibility identities in `doc/BRANDING.md`.

## Repository Language

- Provide paired Chinese/English website and handbook pages with a visible top-header switch.
  Keep Chinese as the default and use /en/ for English. Keep translations in sync.
- Default the public website, user handbook, and main README to Chinese, following the verified
  Chinese podcast workflow. Keep source prose, UI labels, diagnostics, comments, and configuration
  identifiers in English. English engineering references and original research measurements may remain.
- Preserve reviewed translations, ASR prompts/rules, multilingual fixtures, and original benchmark
  input identifiers. `language-assets.json` documents exact resources and embedded-line exceptions.
- Register Chinese-first documentation and localized resources as exact files in language-assets.json.
  New language data also needs a concrete translation or language-processing purpose; never whitelist
  whole source directories. Language options do not establish validation parity with Chinese.
- Run `python configs/check_repository_language.py`; CI and Pages enforce the same policy.
