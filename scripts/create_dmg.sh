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
README_PATH="${REPO_ROOT}/release/README.txt"
DMG_NAME="CursorFlock-${VERSION}-macos.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
STAGING_DIR="${OUTPUT_DIR}/dmg-staging"
MOUNT_ROOT="${OUTPUT_DIR}/dmg-mount"
MOUNT_POINT="${MOUNT_ROOT}/Cursor Flock ${VERSION}"

[[ -d "${APP_PATH}" ]] || fail "app not found at ${APP_PATH}; run scripts/build_release.sh first"
[[ -f "${README_PATH}" ]] || fail "release README not found at ${README_PATH}"

echo "==> Creating DMG ${DMG_PATH}"
rm -rf "${STAGING_DIR}" "${MOUNT_POINT}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}" "${MOUNT_ROOT}"

ditto "${APP_PATH}" "${STAGING_DIR}/Cursor Flock.app"
ln -s /Applications "${STAGING_DIR}/Applications"
cp "${README_PATH}" "${STAGING_DIR}/README.txt"

hdiutil create \
  -volname "Cursor Flock ${VERSION}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

[[ -f "${DMG_PATH}" ]] || fail "DMG was not created at ${DMG_PATH}"

mkdir -p "${MOUNT_POINT}"
hdiutil attach "${DMG_PATH}" -nobrowse -readonly -mountpoint "${MOUNT_POINT}" >/dev/null
cleanup() {
  if mount | grep -q "${MOUNT_POINT}"; then
    hdiutil detach "${MOUNT_POINT}" >/dev/null
  fi
  rm -rf "${MOUNT_POINT}"
}
trap cleanup EXIT

[[ -d "${MOUNT_POINT}/Cursor Flock.app" ]] || fail "mounted DMG does not contain Cursor Flock.app"
[[ -e "${MOUNT_POINT}/Applications" ]] || fail "mounted DMG does not contain Applications shortcut"
[[ -f "${MOUNT_POINT}/README.txt" ]] || fail "mounted DMG does not contain README.txt"

cleanup
trap - EXIT
rm -rf "${STAGING_DIR}" "${MOUNT_ROOT}"

echo "success: created and verified mountable DMG"
echo "dmg: ${DMG_PATH}"
