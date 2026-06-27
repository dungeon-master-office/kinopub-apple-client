#!/usr/bin/env bash
#
# Package a built KinoPub.app into a drag-to-install .dmg.
#
# The disk image contains:
#   • KinoPub.app
#   • an "Applications" symlink (drag to install), and
#   • "Install KinoPub.command" — copies the app to /Applications, strips the Gatekeeper quarantine
#     (xattr -dr com.apple.quarantine) and launches it, so an unsigned/unnotarized build just works.
#
# Usage: ./scripts/build-dmg.sh [path/to/KinoPub.app]
#   Defaults to the app produced by scripts/build-macos.sh.
#
set -euo pipefail

APP_NAME="KinoPub"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${1:-${ROOT_DIR}/build-macos/Build/Products/Release/${APP_NAME}.app}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "!! App not found at ${APP_PATH}. Build it first (scripts/build-macos.sh) or pass the path." >&2
  exit 1
fi

MARKETING_VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/version.txt" 2>/dev/null || true)"
MARKETING_VERSION="${MARKETING_VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DMG_PATH="${DIST_DIR}/${APP_NAME}-macOS-${MARKETING_VERSION}-${BUILD_NUMBER}.dmg"

mkdir -p "${DIST_DIR}"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

echo "==> Staging disk image contents"
cp -R "${APP_PATH}" "${STAGE}/${APP_NAME}.app"
ln -s /Applications "${STAGE}/Applications"

# One-click installer that also clears the Gatekeeper quarantine.
cat > "${STAGE}/Install ${APP_NAME}.command" <<'CMD'
#!/bin/bash
# Installs KinoPub to /Applications and removes the Gatekeeper quarantine so the unsigned build opens.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "Installing KinoPub…"
rm -rf "/Applications/KinoPub.app"
cp -R "$HERE/KinoPub.app" "/Applications/KinoPub.app"
xattr -dr com.apple.quarantine "/Applications/KinoPub.app" 2>/dev/null || true
echo "Done. Launching KinoPub…"
open "/Applications/KinoPub.app"
CMD
chmod +x "${STAGE}/Install ${APP_NAME}.command"

cat > "${STAGE}/READ ME — first launch.txt" <<'TXT'
KinoPub — установка на macOS
============================

Способ 1 (проще всего):
  Дважды кликните «Install KinoPub.command».
  Если macOS скажет, что не может проверить разработчика — кликните по файлу
  ПРАВОЙ кнопкой → «Открыть» → «Открыть».
  Скрипт скопирует приложение в «Программы», снимет карантин и запустит его.

Способ 2 (вручную):
  Перетащите KinoPub.app на ярлык «Applications».
  Если при первом запуске macOS блокирует приложение
  («Apple не удалось проверить, что … не содержит вредоносного ПО»),
  откройте Терминал и выполните:

      xattr -dr com.apple.quarantine /Applications/KinoPub.app

  затем запустите KinoPub из «Программ».

Почему так: приложение не нотаризовано Apple (для этого нужен платный
аккаунт разработчика), поэтому Gatekeeper его придерживает. Снятие карантина —
стандартный и безопасный способ для open-source сборок.
TXT

echo "==> Creating ${DMG_PATH}"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE}" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "${DMG_PATH}" >/dev/null

echo ""
echo "✅ Done"
echo "   DMG:     ${DMG_PATH}"
echo "   Version: ${MARKETING_VERSION} (${BUILD_NUMBER})"
