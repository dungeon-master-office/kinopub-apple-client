#!/usr/bin/env bash
#
# Build an unsigned .ipa of KinoPub for AltStore sideloading.
#
# The artifact is unsigned (CODE_SIGNING_ALLOWED=NO) and carries an
# anonymized bundle identifier — nothing ties it to your developer team.
# AltStore re-signs it with the installing user's own Apple ID on the device,
# so you can just drop the .ipa in Telegram and friends install it via AltStore.
#
# Usage:
#   ./scripts/build-ipa.sh                       # bundle id com.kino.pub
#   BUNDLE_ID=com.foo.bar ./scripts/build-ipa.sh # custom bundle id
#
set -euo pipefail

# ---- config -----------------------------------------------------------------
PROJECT="KinoPubAppleClient.xcodeproj"
SCHEME="KinoPubAppleClient"
CONFIGURATION="Release"
APP_NAME="KinoPub"                       # PRODUCT_NAME -> KinoPub.app
BUNDLE_ID="${BUNDLE_ID:-com.kino.pub}"   # override via env
# -----------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
DIST_DIR="${ROOT_DIR}/dist"
PRODUCTS_DIR="${BUILD_DIR}/Build/Products/${CONFIGURATION}-iphoneos"

cd "${ROOT_DIR}"

# Version: Release Please manages version.txt (the SemVer marketing version); the build number comes
# from CI (the run number) or defaults to 1 locally. Both are injected at build time so the project
# file doesn't need to be edited per release.
MARKETING_VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/version.txt" 2>/dev/null || true)"
MARKETING_VERSION="${MARKETING_VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

echo "==> Cleaning previous build"
rm -rf "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

echo "==> Building ${SCHEME} (${CONFIGURATION}) for device, unsigned, bundle id: ${BUNDLE_ID}, version: ${MARKETING_VERSION} (${BUILD_NUMBER})"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphoneos \
  -derivedDataPath "${BUILD_DIR}" \
  -destination "generic/platform=iOS" \
  -skipPackagePluginValidation \
  PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
  MARKETING_VERSION="${MARKETING_VERSION}" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

APP_PATH="${PRODUCTS_DIR}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "!! Expected app not found at ${APP_PATH}" >&2
  echo "   Built products:" >&2
  ls -1 "${PRODUCTS_DIR}" >&2 || true
  exit 1
fi

# Derive a version label for the filename from the built Info.plist.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_PATH}/Info.plist" 2>/dev/null || echo "0")"
BUILDNUM="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP_PATH}/Info.plist" 2>/dev/null || echo "0")"
IPA_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-${BUILDNUM}.ipa"

echo "==> Packaging .ipa"
STAGE_DIR="$(mktemp -d)"
mkdir -p "${STAGE_DIR}/Payload"
cp -R "${APP_PATH}" "${STAGE_DIR}/Payload/"
( cd "${STAGE_DIR}" && zip -qry "${IPA_PATH}" Payload )
rm -rf "${STAGE_DIR}"

echo ""
echo "✅ Done"
echo "   IPA:        ${IPA_PATH}"
echo "   Bundle ID:  ${BUNDLE_ID}"
echo "   Version:    ${VERSION} (${BUILDNUM})"
echo ""
echo "   Send the .ipa via Telegram. Recipients install it through AltStore"
echo "   (AltStore re-signs with their own Apple ID — unsigned is expected)."
