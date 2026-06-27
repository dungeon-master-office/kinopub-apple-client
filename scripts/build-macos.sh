#!/usr/bin/env bash
#
# Build a macOS .app of KinoPub and zip it for distribution.
#
# The app is ad-hoc signed (no Developer ID / team) and carries an anonymized bundle identifier.
# Because it isn't notarized, macOS Gatekeeper will quarantine it after download — users open it via
# right-click → Open the first time, or run:  xattr -dr com.apple.quarantine /Applications/KinoPub.app
#
# Usage:
#   ./scripts/build-macos.sh                        # bundle id com.kino.pub
#   BUNDLE_ID=com.foo.bar ./scripts/build-macos.sh  # custom bundle id
#
set -euo pipefail

# ---- config -----------------------------------------------------------------
PROJECT="KinoPubAppleClient.xcodeproj"
SCHEME="KinoPubAppleClient"
CONFIGURATION="Release"
APP_NAME="KinoPub"
BUNDLE_ID="${BUNDLE_ID:-com.kino.pub}"
# -----------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build-macos"
DIST_DIR="${ROOT_DIR}/dist"
PRODUCTS_DIR="${BUILD_DIR}/Build/Products/${CONFIGURATION}"

cd "${ROOT_DIR}"

MARKETING_VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/version.txt" 2>/dev/null || true)"
MARKETING_VERSION="${MARKETING_VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

echo "==> Cleaning previous macOS build"
rm -rf "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

echo "==> Building ${SCHEME} (${CONFIGURATION}) for macOS, ad-hoc signed, bundle id: ${BUNDLE_ID}, version: ${MARKETING_VERSION} (${BUILD_NUMBER})"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "platform=macOS" \
  -derivedDataPath "${BUILD_DIR}" \
  -skipPackagePluginValidation \
  PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
  MARKETING_VERSION="${MARKETING_VERSION}" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  build

APP_PATH="${PRODUCTS_DIR}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "!! Expected app not found at ${APP_PATH}" >&2
  ls -1 "${PRODUCTS_DIR}" >&2 || true
  exit 1
fi

ZIP_PATH="${DIST_DIR}/${APP_NAME}-macOS-${MARKETING_VERSION}-${BUILD_NUMBER}.zip"
echo "==> Zipping (ditto, preserves bundle + signature)"
rm -f "${ZIP_PATH}"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo ""
echo "✅ Done"
echo "   App:        ${APP_PATH}"
echo "   Zip:        ${ZIP_PATH}"
echo "   Bundle ID:  ${BUNDLE_ID}"
echo "   Version:    ${MARKETING_VERSION} (${BUILD_NUMBER})"
