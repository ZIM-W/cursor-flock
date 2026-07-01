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

OUTPUT_DIR="${REPO_ROOT}/release-output"
APP_PATH="${OUTPUT_DIR}/Cursor Flock.app"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"
DMG_NAME="CursorFlock-${VERSION}-macos.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
NOTES_PATH="${OUTPUT_DIR}/CursorFlock-${VERSION}-release-notes.md"
MOUNT_ROOT="${OUTPUT_DIR}/verify-mount"
MOUNT_POINT="${MOUNT_ROOT}/Cursor Flock ${VERSION}"

echo "==> Verifying release artifacts for ${VERSION}"

[[ -d "${APP_PATH}" ]] || fail "release app does not exist at ${APP_PATH}"
[[ -f "${INFO_PLIST}" ]] || fail "Info.plist does not exist at ${INFO_PLIST}"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${INFO_PLIST}")"
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")"
LS_UI_ELEMENT="$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "${INFO_PLIST}")"

[[ -n "${BUNDLE_ID}" ]] || fail "bundle identifier is empty"
[[ -n "${APP_VERSION}" ]] || fail "version is empty"
[[ "${LS_UI_ELEMENT}" == "true" || "${LS_UI_ELEMENT}" == "1" ]] || fail "LSUIElement is not enabled; app may not be menu-bar-only"

codesign --verify --verbose=2 "${APP_PATH}"

[[ -f "${DMG_PATH}" ]] || fail "DMG does not exist at ${DMG_PATH}"

if [[ ! -f "${NOTES_PATH}" ]]; then
  echo "release notes missing; generating ${NOTES_PATH}"
  "${REPO_ROOT}/scripts/create_github_release_notes.sh" "${VERSION}"
fi
[[ -f "${NOTES_PATH}" ]] || fail "release notes do not exist at ${NOTES_PATH}"

rm -rf "${MOUNT_POINT}"
mkdir -p "${MOUNT_POINT}"
hdiutil attach "${DMG_PATH}" -nobrowse -readonly -mountpoint "${MOUNT_POINT}" >/dev/null
cleanup() {
  if mount | grep -q "${MOUNT_POINT}"; then
    hdiutil detach "${MOUNT_POINT}" >/dev/null
  fi
  rm -rf "${MOUNT_POINT}"
}
trap cleanup EXIT

[[ -d "${MOUNT_POINT}/Cursor Flock.app" ]] || fail "DMG does not contain Cursor Flock.app"
[[ -e "${MOUNT_POINT}/Applications" ]] || fail "DMG does not contain Applications shortcut"
[[ -f "${MOUNT_POINT}/README.txt" ]] || fail "DMG does not contain README.txt"

cleanup
trap - EXIT
rm -rf "${MOUNT_ROOT}"

echo "success: release verification passed"
echo "bundle id: ${BUNDLE_ID}"
echo "version: ${APP_VERSION}"
echo "dmg: ${DMG_PATH}"
echo "release notes: ${NOTES_PATH}"
