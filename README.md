# Reflex

Reflex is a SwiftUI-native macOS app for examining local, privacy-bounded
context alongside deterministic mock decisions. This repository currently
contains the Phase 2 local-context foundation.

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

## Run the app

Open `Reflex.xcodeproj` in Xcode, select the **Reflex** scheme, and press
`Command-R`. The app provides a main window and a menu-bar control for opening
the app, pausing or resuming local context capture, capturing context, opening
Settings, and quitting.

## Local context controls

Reflex can capture the frontmost application's name and bundle identifier,
then keeps a bounded recent-app history. Capture happens when you choose
**Capture local context** or after a frontmost-app change, subject to a
one-second debounce and the configurable minimum capture interval.

The capture controls are available in the Lens, the menu bar, and Settings:

- Pause or resume all local context capture.
- Enable active-window metadata only by selecting **Enable window metadata
  access**. Reflex then asks macOS for Accessibility permission; without that
  permission, it stays in reduced-context mode and does not read window titles.
- Enable **Include clipboard in local captures** only if you want it. This
  option is off by default. Clipboard text is bounded before it enters the
  in-memory snapshot.
- Clear the currently displayed local snapshot from the app.

The Lens shows the captured local snapshot and the exact sanitized payload
that a future Jev integration could use. Application names, window titles, and
clipboard text are redacted from that payload; only safe descriptors such as a
bundle identifier, clipboard content type, length, and truncation state remain.

## API key

Open **Reflex → Settings…**, enter a Jev API key, then choose **Save key**.
Reflex stores the key in your macOS Keychain and never displays its value.

The key is stored only. Phase 2 remains mock-only: it does not use the key to
contact Jev. Selecting the visible Live Jev option does not enable a request;
live decisions arrive in Phase 3.

## Privacy boundary

Context stays on the Mac in mock mode, and no Jev request is made. Reflex does
not perform keylogging, take screenshots, use the camera or microphone, read
full documents, or continuously inspect clipboard contents. It requests
Accessibility permission only after an explicit user action to enable
active-window metadata. Clipboard capture is separately opt-in and off by
default.
