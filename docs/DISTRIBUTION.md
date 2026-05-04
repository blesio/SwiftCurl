# Distribution

## Build A Zip

```bash
./script/build_and_run.sh --package
```

The distributable archive is written to:

```text
dist/SwiftCurl.zip
```

## Signing

The build script signs the app bundle after staging it.

By default it uses ad-hoc signing:

```bash
codesign --force --sign - dist/SwiftCurl.app
```

This gives the app a valid code signature, but it is not a Developer ID signature and is not notarized. Other Macs may still show an unknown developer warning.

## Developer ID Signing

If a Developer ID Application certificate is installed, set `CODESIGN_IDENTITY`:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name" ./script/build_and_run.sh --package
```

The script will sign with hardened runtime and timestamp options.

## Verify Signing

```bash
codesign --verify --deep --strict dist/SwiftCurl.app
codesign -dvvv dist/SwiftCurl.app
spctl -a -vv dist/SwiftCurl.app
```

`spctl` rejection is expected for ad-hoc signed, non-notarized apps.

## Architecture

The current local build produces an Apple Silicon `arm64` binary. A universal build requires a local Xcode setup that supports SwiftPM multi-architecture builds.
