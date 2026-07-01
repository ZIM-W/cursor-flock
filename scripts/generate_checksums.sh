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
DMG_NAME="CursorFlock-${VERSION}-macos.dmg"
CHECKSUM_NAME="${DMG_NAME}.sha256"

[[ -f "${OUTPUT_DIR}/${DMG_NAME}" ]] || fail "DMG does not exist at ${OUTPUT_DIR}/${DMG_NAME}"

echo "==> Generating SHA-256 checksum"
(
  cd "${OUTPUT_DIR}"
  shasum -a 256 "${DMG_NAME}" > "${CHECKSUM_NAME}"
)

echo "success: checksum written"
echo "checksum: ${OUTPUT_DIR}/${CHECKSUM_NAME}"
