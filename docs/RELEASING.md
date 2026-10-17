# Releasing

Releases are built and published by
[`release.yml`](https://github.com/Kyonru/love-thorvg/blob/main/.github/workflows/release.yml).
Pushing a tag named
`v<major>.<minor>.<patch>` builds and tests the native library on macOS ARM64,
macOS x64, Linux x64, and Windows x64. The workflow packages one ZIP for each
target, validates and combines those packages into an `all-desktop` ZIP, and
creates a GitHub release with generated notes after every build succeeds.

## Prepare a release

1. Set the release version in `meson.build`.
2. Add a dated entry for the same version to
   [`CHANGELOG.md`](https://github.com/Kyonru/love-thorvg/blob/main/CHANGELOG.md).
3. Run the release metadata check and the local build:

   ```sh
   python3 scripts/check_release.py v0.1.0
   PATH="$PWD/.venv/bin:$PATH" ./scripts/build.sh
   ```

4. Commit the release preparation and make sure the `main` branch is green.

The tag, Meson version, and changelog entry must agree. The release workflow
checks all three before doing a native build.

## Publish a release

Create an annotated tag on the prepared commit and push it:

```sh
git tag -a v0.1.0 -m "love-thorvg v0.1.0"
git push origin main
git push origin v0.1.0
```

The tag push is the publication trigger. Do not create the GitHub release by
hand while the workflow is running. If any platform fails, no release is
created; fix the failure, delete the failed remote tag, and prepare a new tag
only after confirming that no release was published.

## Release archives

Each archive is named `love-thorvg-v<version>-<platform>-<architecture>.zip`
and contains:

```text
love_thorvg/
├── init.lua
├── view.lua
└── native/<platform>-<architecture>/<library>
README.md
LICENSE
THORVG-LICENSE
```

The four target archives intentionally contain one native target each. The
release also contains `love-thorvg-v<version>-all-desktop.zip`, which has all
four directories in one package. `scripts/combine_packages.py` normalizes text
line endings and verifies all shared Lua, documentation, and license content
before it creates that archive.
