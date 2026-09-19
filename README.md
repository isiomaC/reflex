# Reflex

Reflex is a SwiftUI-native macOS app for viewing a small, transparent sample
context and a deterministic mock decision. This repository currently contains
the Phase 1 foundation only.

## Requirements

- macOS 14 or later
- Xcode 26.1 or later

The Xcode project resolves [JevKit](https://github.com/isiomaC/jevkit) as a
Swift Package dependency from version `0.1.0`.

## Build and test

Open `Reflex.xcodeproj` in Xcode, or use the command line:

```sh
xcodebuild -project Reflex.xcodeproj -scheme Reflex -configuration Debug build
xcodebuild -project Reflex.xcodeproj -scheme Reflex -configuration Debug test
```

## API key

Open **Reflex → Settings…**, enter a Jev API key, then choose **Save key**.
Reflex stores the key in your macOS Keychain and never displays its value.

In this Phase 1 build, the key is stored only: the app remains in mock-only
mode and does not use the key to contact Jev.

## Privacy boundary

Phase 1 uses only in-app sample context. It does not collect desktop context,
read the clipboard, request system permissions, or send Jev network traffic.
