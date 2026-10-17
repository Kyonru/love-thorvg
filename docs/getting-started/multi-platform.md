# Multi-platform bundle

Releases provide one archive per desktop target and an
`all-desktop` archive containing all four native libraries:

```text
love_thorvg/native/
├── linux-x64/liblove_thorvg.so
├── macos-arm64/liblove_thorvg.dylib
├── macos-x64/liblove_thorvg.dylib
└── windows-x64/love_thorvg.dll
```

Choose a target-specific archive when download size matters. Choose
`love-thorvg-v<version>-all-desktop.zip` when one source tree or build pipeline
needs to package macOS, Linux, and Windows games.

Yes, the combined archive is assembled from the four target archives. The
release job does more than concatenate ZIPs: it rejects unsafe paths, normalizes
checkout-specific text line endings, verifies that every shared file has the
same content, detects conflicting native paths, and then writes one clean
archive with a single top-level folder.

The runtime still loads only the library matching the current OS and CPU. The
extra libraries add distribution size but not runtime memory use. This bundle
does not add browser support; web uses the separately documented experimental
WebAssembly architecture.

To reproduce the bundle from downloaded release assets:

```sh
python3 scripts/combine_packages.py downloads dist --version v0.2.0
```
