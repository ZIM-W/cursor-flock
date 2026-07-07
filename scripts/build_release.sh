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

PROJECT="CursorFlock.xcodeproj"
SCHEME="CursorFlock"
CONFIGURATION="Release"
OUTPUT_ROOT="${REPO_ROOT}/release-output"
OUTPUT_DIR="${OUTPUT_ROOT}/${VERSION}"
DERIVED_DATA="${OUTPUT_DIR}/DerivedData"
APP_OUTPUT="${OUTPUT_DIR}/Cursor Flock.app"
SOURCE_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/CursorFlock.app"
BUILD_INFO="${OUTPUT_DIR}/build-info.txt"

echo "==> Building Cursor Flock ${VERSION} (${CONFIGURATION})"
mkdir -p "${OUTPUT_DIR}"
rm -rf "${DERIVED_DATA}" "${APP_OUTPUT}"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  -destination "generic/platform=macOS" \
  clean build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  MACOSX_DEPLOYMENT_TARGET=13.0 \
  MARKETING_VERSION="${VERSION}" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
  ONLY_ACTIVE_ARCH=NO \
  "ARCHS=arm64 x86_64"

[[ -d "${SOURCE_APP}" ]] || fail "release app was not produced at ${SOURCE_APP}"

ditto "${SOURCE_APP}" "${APP_OUTPUT}"
[[ -d "${APP_OUTPUT}" ]] || fail "failed to copy app to ${APP_OUTPUT}"

EXECUTABLE="${APP_OUTPUT}/Contents/MacOS/CursorFlock"
[[ -x "${EXECUTABLE}" ]] || fail "app executable is missing at ${EXECUTABLE}"

ARCHITECTURES="$(lipo -archs "${EXECUTABLE}")"
{
  echo "Cursor Flock ${VERSION}"
  echo "Configuration: ${CONFIGURATION}"
  echo "Minimum macOS: 13.0"
  echo "Architectures: ${ARCHITECTURES}"
  echo "App: ${APP_OUTPUT}"
} > "${BUILD_INFO}"

echo "success: built app"
echo "app: ${APP_OUTPUT}"
echo "architectures: ${ARCHITECTURES}"
echo "build info: ${BUILD_INFO}"
