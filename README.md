# SwiftCurl

SwiftCurl is a native macOS REST and cURL client built with SwiftUI. It is meant to feel like a lightweight Postman-style workspace for saving API requests in project folders, sending them quickly, and inspecting responses without leaving a desktop app.

## Features

- Native SwiftUI macOS interface
- Project folders with collapsible request lists
- Saved REST requests with method, URL, query parameters, headers, JSON body, notes, and settings
- Authentication modes:
  - None
  - Basic auth
  - Bearer token with show/hide toggle
  - API key in header or query string
- cURL import and generated cURL export
- Per-request HTTPS setting to allow invalid SSL certificates for local/internal systems
- Response viewer with status, timing, headers, and body
- Large-response friendly body rendering
- MP3/WAV response detection with built-in audio playback
- Save response bodies to disk
- Cached responses are restored when the app reopens
- Project import/export
- Ad-hoc signed `.app` packaging script

## Requirements

- macOS 14 or newer
- Swift 5.9 or newer
- Xcode command line tools

## Build

```bash
swift build
```

## Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM executable, stages a real macOS `.app` bundle in `dist/SwiftCurl.app`, copies the app icon, signs the bundle, and launches it.

## Package

```bash
./script/build_and_run.sh --package
```

This creates:

```text
dist/SwiftCurl.zip
```

By default the app is ad-hoc signed. That means it can still be blocked by Gatekeeper as coming from an unidentified developer, but the bundle has a valid local code signature.

If you have a Developer ID certificate installed, package with:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name" ./script/build_and_run.sh --package
```

## App Icon

The app icon is generated from `curl icon.png`.

Regenerate icon assets with:

```bash
swift Tools/GenerateAppIcon.swift
```

This writes:

- `Resources/AppIcon-1024.png`
- `Resources/AppIcon.icns`
- `Resources/AppIcon.iconset/`

## Project Data

SwiftCurl stores projects and cached responses in the user Application Support folder:

```text
~/Library/Application Support/SwiftCurl/projects.json
```

Projects can also be exported and imported from the sidebar Project menu.

## Development Notes

- The app is a Swift Package Manager executable target.
- GUI bundle staging happens in `script/build_and_run.sh`.
- The generated `.app` is intentionally not checked into git.
- Cached binary responses, such as audio, are persisted as base64 inside the app storage JSON.

## Repository Layout

```text
Sources/SwiftCurl/App/          App entry point
Sources/SwiftCurl/Models/       Codable request, project, auth, response models
Sources/SwiftCurl/Services/     Networking, persistence, cURL import/export
Sources/SwiftCurl/Stores/       App state and actions
Sources/SwiftCurl/Views/        SwiftUI and AppKit-backed views
Resources/                      App icon assets
Tools/                          Local helper scripts
script/                         Build, run, sign, and package script
docs/                           Additional documentation
```
