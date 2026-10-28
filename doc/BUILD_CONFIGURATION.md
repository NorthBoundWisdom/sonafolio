# Build configuration

The repository's build scripts read an optional root `build.local.json` through
`configs/build_environment.py`. The file is ignored by Git and edited directly on
each machine. There is no dependency lock, dependency mode or seed workflow.
The optional FreeCM plugin invokes the same scripts through `configs/freecm.commands.jsonc`.
Its `configs/source_root_workflow.py` entrypoint is a thin setup/cleanup adapter.

## Machine-local environment

The tracked template is `configs/build.local.example.json`. Running either
`python3 configs/setup_local_app.py` or `python3 configs/qt_workflow.py config` creates
root `build.local.json` from it when the local file is missing. Existing files are
never replaced or merged, including after template updates. Help and ordinary
environment reads do not create the file.

The template leaves SDK, dependency and signing paths empty. Fill them in for your
machine, then run configuration again. Generating the file never locates SDKs
automatically; GeoControls is prepared by Qt configuration as described below.
You can also copy the template manually before the first configuration.

For example, edit the generated `build.local.json`:

```json
{
  "environment": {
    "AUDIO2TEXTQT_QT_PREFIX": "$HOME/Qt/6.12.0/macos",
    "CMAKE_BUILD_PARALLEL_LEVEL": "4",
    "ARCHIVE_ID": "2"
  },
  "path": [
    "$AUDIO2TEXTQT_QT_PREFIX/bin"
  ]
}
```

Choose paths for SDKs and checkouts already present on your machine. Windows may
set `VCPKG_ROOT`, `AUDIO2TEXTQT_QT_PREFIX` and `AUDIO2TEXTQT_FFMPEG_DIR` in the same
`environment` object. Keys have no platform-specific nesting because the file is local.

All values are strings. `$VAR`, `${VAR}` and `%VAR%` reference environment variables;
`${REPO_ROOT}` refers to this repository. PATH entries in `path` are prepended and
relative entries resolve from the repository root. Tilde expansion uses the local
home directory. No shell code is executed. Invalid JSON, missing variables and
cyclic references fail explicitly.

Explicit command options take precedence over the effective environment. Variables
already supplied by the caller take precedence over file values, allowing CI or a
single command to override local settings. Configured PATH entries are prepended
without duplicates. Settings apply for one command and are restored when it returns.
A missing local file leaves the caller's environment unchanged.

Swift setup/build/package, Xcode metadata generation, Qt workflows and CI scripts
share this configuration. `configs/app_build.json` holds public version defaults;
`MARKETING_VERSION`, `ARCHIVE_ID` and `XCODE_DEVELOPMENT_TEAM` in the environment
provide local overrides. `ATOT_RELEASE_VERSION` selects the CI version and archive
ID `1`. The environment file, signing settings and SDK paths must remain untracked.

## Local Qt dependencies

`configs/dependencies.json` pins GeoControls by HTTPS remote and full commit.
`python3 configs/qt_workflow.py config` fetches that commit into ignored
`build/dependencies/GeoControls` when it is missing, and moves a clean checkout to a new
pin. A checkout with local changes or a non-Git directory at that path fails instead of
being replaced. `build` consumes the source recorded by configuration, and
`source_root_workflow.py --cleanbuild` keeps the dependency checkout.

To develop against another checkout, set `GEOCONTROLS_SOURCE_ROOT` in the local file or
pass `--geocontrols-source`; a path other than the default is used as-is and never
fetched. `qt/Audio2TextQt/cmake/GeoControls.cmake` only validates and adds the source
directory, so a direct CMake invocation must pass `-DGEOCONTROLS_SOURCE_ROOT=...`.

```bash
python3 configs/qt_workflow.py config --configuration Release
python3 configs/qt_workflow.py build --configuration Release
```

CI prepares the exact revision in a separate, explicitly named checkout step in
`.github/workflows/release.yml` before configuring the client. Packaging reads the
resolved source from the CMake cache, requires a clean Git checkout and records its
actual revision and MIT license. Qt and vcpkg SDKs must already be installed for local
builds. `VCPKG_ROOT` selects its CMake toolchain unless `CMAKE_TOOLCHAIN_FILE` is supplied.

Backups of retired local settings may live under ignored `build/retired-config/`.
