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
APP_PATH="${OUTPUT_DIR}/Cursor Flock.app"
[[ -d "${APP_PATH}" ]] || fail "app not found at ${APP_PATH}; run scripts/build_release.sh first"

echo "==> Ad-hoc signing ${APP_PATH}"
echo "note: ad-hoc signing does not provide Developer ID trust and does not prevent macOS Gatekeeper warnings on other machines."

sign_path() {
  local path="$1"
  echo "signing nested code: ${path}"
  codesign --force --sign - "${path}"
}

if [[ -d "${APP_PATH}/Contents/Frameworks" ]]; then
  while IFS= read -r framework; do
    sign_path "${framework}"
  done < <(find "${APP_PATH}/Contents/Frameworks" -type d -name "*.framework" -prune)

  while IFS= read -r binary; do
    sign_path "${binary}"
  done < <(find "${APP_PATH}/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm -111 \))
fi

for nested_dir in PlugIns XPCServices Helpers Library; do
  if [[ -d "${APP_PATH}/Contents/${nested_dir}" ]]; then
    while IFS= read -r nested_code; do
      sign_path "${nested_code}"
    done < <(find "${APP_PATH}/Contents/${nested_dir}" \( -name "*.appex" -o -name "*.xpc" -o -name "*.app" -o -name "*.framework" \) -prune)

    while IFS= read -r nested_binary; do
      sign_path "${nested_binary}"
    done < <(find "${APP_PATH}/Contents/${nested_dir}" -type f \( -name "*.dylib" -o -perm -111 \))
  fi
done

echo "signing outer app: ${APP_PATH}"
codesign --force --sign - "${APP_PATH}"
codesign --verify --verbose=2 "${APP_PATH}"

echo "success: ad-hoc signature verified"
