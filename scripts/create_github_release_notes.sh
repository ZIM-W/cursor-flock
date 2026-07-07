#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

VERSION="${1:-${VERSION:-}}"
[[ -n "${VERSION}" ]] || fail "set VERSION=0.1.0 or pass the version as the first argument"

OUTPUT_DIR="${REPO_ROOT}/release-output/${VERSION}"
NOTES_PATH="${OUTPUT_DIR}/CursorFlock-${VERSION}-release-notes.md"

mkdir -p "${OUTPUT_DIR}"

cat > "${NOTES_PATH}" <<NOTES
## Cursor Flock v${VERSION} — Preview
A lightweight macOS menu bar utility that turns the system cursor into a decorative flock.
### Highlights
- Live system cursor appearance copying
- Decorative cursor flock with multiple patterns and presets
- Opacity, scale, orientation, speed, distance, frame-rate, and idle controls
- Launch at Login support
- Local settings persistence
### Requirements
- macOS 13 or later
### Installation
1. Download \`CursorFlock-${VERSION}-macos.dmg\`.
2. Open the DMG.
3. Drag Cursor Flock into Applications.
4. Launch it from Applications.
5. If macOS blocks the app because the developer cannot be verified, open System Settings → Privacy & Security → Open Anyway.
### Important
This is a free preview build distributed through GitHub Releases.
It is not notarized by Apple, so macOS may show a security warning on first launch.
### Privacy
Cursor Flock does not collect analytics or telemetry.
It does not upload cursor positions, store mouse trajectories, capture screenshots, inspect application content, inject input, or automate clicks.
### License
PolyForm Noncommercial License 1.0.0.
Commercial use requires prior written permission.
### Verification
Verify the downloaded DMG using the included SHA-256 checksum file.
NOTES

echo "success: release notes written"
echo "release notes: ${NOTES_PATH}"
