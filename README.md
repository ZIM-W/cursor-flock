# Cursor Flock

Cursor Flock is a lightweight macOS menu-bar utility that turns the real system cursor into a decorative visual flock. The real macOS cursor remains visible, fully functional, and the only interactive cursor.

## Requirements

- macOS 13 or later
- Xcode 16 or later for development builds

## Features

- Transparent click-through overlays, one per display
- Live system cursor image and hotspot copying
- Decorative flock-centred cursor members around the real cursor
- Multiple flock patterns and quick presets
- Speed, distance, opacity, scale, orientation, frame-rate, and idle controls
- Launch at Login support
- Local settings persistence with UserDefaults
- Cached cursor render resources, persistent layer pools, and display-local filtering to reduce system impact

Cursor Flock does not use Electron, Tauri, web technologies, screenshots, input injection, accessibility automation, telemetry, analytics, cloud sync, or network services.

## Install From GitHub Releases

1. Download `CursorFlock-VERSION-macos.dmg` and `CursorFlock-VERSION-macos.dmg.sha256` from GitHub Releases.
2. Verify the checksum:

```sh
shasum -a 256 -c CursorFlock-VERSION-macos.dmg.sha256
```

3. Open the DMG.
4. Drag `Cursor Flock.app` into Applications.
5. Launch Cursor Flock from Applications.

This preview build is ad-hoc signed only and is not notarized by Apple. On first launch, macOS may block it because the developer cannot be verified. If you choose to open it, use System Settings > Privacy & Security > Open Anyway. Do not disable Gatekeeper globally.

## Usage

After launch, use the Cursor Flock icon in the macOS menu bar to enable, disable, and configure the flock.

The menu includes:

- Enable Cursor Flock
- Launch at Login
- Quick Presets
- Pattern and Pattern Parameters
- Cursor Count
- Flock Distance
- Flock Speed and Speed Variation
- Frame Rate
- Opacity
- Scale & Depth
- Orientation
- Idle Behaviour
- Restore Default Settings
- Quit

## Privacy

Cursor Flock does not collect analytics or telemetry. It does not upload cursor positions, save mouse trajectories, capture screenshots, inspect application content, inject input, automate clicks, or replace the real system cursor. Decorative cursors are visual-only. Settings are stored locally using UserDefaults.

See [docs/PRIVACY.md](docs/PRIVACY.md).

## Build For Development

Open `CursorFlock.xcodeproj` in Xcode, select the `CursorFlock` scheme, and run with `Cmd-R`.

You can also build from Terminal:

```sh
xcodebuild -project CursorFlock.xcodeproj -scheme CursorFlock -configuration Debug build
```

## Preview Release Builds

The free GitHub Releases preview workflow is documented in [docs/RELEASE.md](docs/RELEASE.md). It builds a Release app, ad-hoc signs it, creates a DMG, verifies the package, generates a SHA-256 checksum, and creates release notes.

Quick command summary:

```sh
export VERSION="0.1.0"
chmod +x scripts/*.sh
./scripts/build_release.sh
./scripts/adhoc_sign_app.sh
./scripts/create_dmg.sh
./scripts/verify_release.sh
./scripts/generate_checksums.sh
./scripts/create_github_release_notes.sh
```

This workflow does not use Developer ID signing, Apple notarization, paid Apple Developer credentials, GitHub APIs, or GitHub CLI.

## Distribution

Preview downloads are provided through GitHub Releases only. See [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).

## License

License: PolyForm Noncommercial License 1.0.0.

Commercial use, resale, paid distribution, hosting as a paid service, or incorporation into commercial products requires prior written permission from the copyright holder.
