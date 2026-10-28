# Development and contribution

Original source is MIT; dependencies, models, and media retain their terms. Chinese is the default with matching English website pages. Code/identifiers keep their real names and historical measurements retain evidence.

## Clients

```bash
git clone https://github.com/NorthBoundWisdom/sonafolio.git
cd sonafolio
python3 configs/setup_local_app.py
python3 configs/ios_workflow.py build --platform mac --scheme Audio2TextApp --configuration debug --distribution ad-hoc
python3 configs/ios_workflow.py build --platform ios --scheme Audio2Text-iOS --configuration debug
```

Mac output is build/app/SonaFolio.app; iOS validates the simulator. Qt uses your SDK/CMake:

```bash
python3 configs/qt_workflow.py config --configuration Release --qt-prefix <Qt-prefix>
python3 configs/qt_workflow.py smoke --configuration Release
```

Use actual local SDK paths without committing them. Backend promotion needs gates/semantic review, not only compilation.


Machine-local settings live in ignored root `build.local.json`. Initial local setup or Qt Config creates a missing file from `configs/build.local.example.json`, preserving existing files. Template paths are empty; fill in local settings and run Config again. `environment` contains SDK/GeoControls paths, signing and version variables, while `path` lists additional tool directories. Swift, Qt, CI scripts and optional FreeCM project commands share the loader without generating lock files.

Qt Config fetches the GeoControls commit pinned in `configs/dependencies.json` into `build/dependencies/GeoControls`, and Build uses that checkout; a checkout with local changes fails instead of being replaced. A `GEOCONTROLS_SOURCE_ROOT` or `--geocontrols-source` pointing elsewhere is used as-is and never fetched. Set the SDK with `AUDIO2TEXTQT_QT_PREFIX`, or use explicit `--qt-prefix` and `--geocontrols-source` workflow options. CI checks out the same pin in a separate step. Packages record the actual revision and MIT license. No FreeCM checkout or installation is required; Config, Build, Run, Test and Package wiring remains available.

## Checks and documentation

```bash
python -m ruff check .
python -m mypy
python -m pytest
python configs/check_docs.py
python configs/check_repository_language.py
```

Use the managed environment. Client READMEs describe Swift/Qt checks.

Website sources are in website/, output in build/website/. Chinese pages keep existing URLs, with index.en.md-style English companions built under en/. Translate all pages together; missing pairs fail documentation validation. Top header links retain the corresponding page. Strict builds/resources/policies precede Pages publication, and generated files, weights, recordings, keys, and libraries stay out of Git.

## Engineering references

- [Repository / English README](https://github.com/NorthBoundWisdom/sonafolio/blob/main/README.en.md)
- [Architecture](https://github.com/NorthBoundWisdom/sonafolio/blob/main/doc/ARCHITECTURE.md)
- [Builds and extension](https://github.com/NorthBoundWisdom/sonafolio/blob/main/doc/TECHNICAL_GUIDE.md)
- [Agent policy](https://github.com/NorthBoundWisdom/sonafolio/blob/main/AGENTS.md)
- [CI/tag releases](https://github.com/NorthBoundWisdom/sonafolio/blob/main/doc/CI_RELEASES.md)
- [Third-party licensing](https://github.com/NorthBoundWisdom/sonafolio/blob/main/doc/RELEASE_LICENSES.md)
- [Website maintenance](https://github.com/NorthBoundWisdom/sonafolio/blob/main/doc/WEBSITE.md)

Research preserves original text/measurements. Package capabilities follow their release, and translated docs do not establish broader ASR validation.
