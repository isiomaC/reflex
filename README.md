# Reflex

Reflex is a SwiftUI-native macOS app for examining local, privacy-bounded
context alongside deterministic mock and live Jev decisions. This repository
currently contains the Phase 3 live Decision Lens.

## Requirements

- macOS 14 or later
- Xcode 26.1 or later

The Xcode project resolves [JevKit](https://github.com/isiomaC/jevkit) as a
Swift Package dependency from version `0.1.1`.

## Build and test

Open `Reflex.xcodeproj` in Xcode, or use the command line:

```sh
xcodebuild -project Reflex.xcodeproj -scheme Reflex -configuration Debug build
xcodebuild -project Reflex.xcodeproj -scheme Reflex -configuration Debug test

# Or use the repository scripts.
./build.sh
./run.sh
```

## Run the app

Open `Reflex.xcodeproj` in Xcode, select the **Reflex** scheme, and press
`Command-R`. The app provides a main window and a menu-bar control for opening
the app, pausing or resuming local context capture, capturing context, opening
Settings, and quitting.

`./run.sh` builds into `.build/` and opens that exact app bundle once. Set
`REFLEX_DERIVED_DATA_PATH` if you want to use a different build directory.

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
- Enable **Include clipboard in explicit captures** only if you want it. This
  option is off by default. Even when enabled, Reflex reads clipboard text only
  when you choose **Capture Clipboard Now**; automatic app-change captures
  never read it. Clipboard text is bounded before it enters the in-memory
  snapshot.
- Clear the currently displayed local snapshot from the app.

The Lens shows the captured local snapshot and the exact sanitized payload used
for a live Jev decision. Application names, window titles, and clipboard text
are redacted from that payload; only safe descriptors such as a bundle
identifier, clipboard content type, length, and truncation state remain.

## API key

Open **Reflex → Settings…**, enter a Jev API key, then choose **Save key**.
Reflex stores the key in your macOS Keychain and never displays its value.

To use Jev, select **Live Jev** in Settings, then capture local context or use
**Refresh live decision**. Reflex sends one request containing three independent
typed judgments—activity, intervention usefulness, and a passive in-app
suggestion—over only the sanitized Lens payload. It never performs desktop
actions from a decision. Responses for superseded snapshots are ignored.

## Privacy boundary

Context stays on the Mac in mock mode, and no Jev request is made. In live mode,
only the exact sanitized payload displayed in Lens is sent to Jev. Reflex does
not perform keylogging, take screenshots, use the camera or microphone, read
full documents, or continuously inspect clipboard contents. It requests
Accessibility permission only after an explicit user action to enable
active-window metadata. Clipboard capture is separately opt-in and off by
default; it is read only through the explicit **Capture Clipboard Now** action.
