# Architecture

SwiftCurl is a small SwiftPM macOS app with a split between models, services, store state, and views.

## App Entry

`SwiftCurlApp` creates the main `WindowGroup`, installs an `NSApplicationDelegate`, and owns the root `RequestStore`.

## State

`RequestStore` is an `@Observable` main-actor store. It owns:

- projects
- selected request
- cached responses keyed by request ID
- send-in-progress state
- cURL import/export text

The store also exposes actions for:

- creating and deleting projects
- renaming projects
- creating and deleting requests
- importing and exporting projects
- importing cURL commands
- sending requests
- formatting JSON bodies

## Persistence

`RequestPersistence` reads and writes a `StoredWorkspace` JSON document in Application Support.

The persisted workspace contains projects and cached responses. Older project-only JSON files are still decoded for migration.

## Networking

`NetworkClient` converts a `RESTRequest` into `URLRequest`, applies auth/query/header/body settings, sends with `URLSession`, and records a `ResponseRecord`.

When a request enables invalid SSL certificate bypass, `NetworkClient` creates a custom `URLSession` with a delegate that accepts server trust challenges for that request.

## Response Rendering

Text responses are rendered by an AppKit-backed `NSTextView` so large bodies remain usable.

Audio responses are detected from `Content-Type` and common file signatures, then played with `AVAudioPlayer` through a custom SwiftUI control strip.

## Bundle Creation

SwiftPM builds a command executable, so `script/build_and_run.sh` stages a minimal `.app` bundle:

- copies the built binary
- writes `Info.plist`
- copies the generated app icon
- signs the bundle
- optionally zips the app for distribution
