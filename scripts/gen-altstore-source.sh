#!/usr/bin/env bash
#
# Generate an AltStore/SideStore source (apps.json) from the repo's GitHub Releases.
#
# Every release that has a *.ipa asset becomes a version entry, so AltStore/SideStore (and Feather,
# which reads the same format) can add this repo as a source and auto-update to the newest build.
#
# The file is published as a release asset, so the stable URL
#   https://github.com/<owner>/<repo>/releases/latest/download/apps.json
# always serves the latest source.
#
# Usage: ./scripts/gen-altstore-source.sh [owner/repo] [output-path]
#
set -euo pipefail

REPO="${1:-${GITHUB_REPOSITORY:-dungeon-master-xx/kinopub-apple-client}}"
OUT="${2:-dist/apps.json}"
RAW="https://raw.githubusercontent.com/${REPO}/main"
ICONSET="${RAW}/KinoPubAppleClient/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Default.png"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$(dirname "${OUT}")"

# JSON array of raw-content URLs for the screenshots in Screenshots/<device> (natural-sorted).
shots_json() {
  local sub="$1"
  ( ls "${ROOT_DIR}/Screenshots/${sub}" 2>/dev/null | grep -iE '\.(jpe?g|png)$' | sort -V ) \
    | while IFS= read -r f; do printf '%s/Screenshots/%s/%s\n' "${RAW}" "${sub}" "${f}"; done \
    | jq -R . | jq -s '.'
}

echo "==> Reading releases of ${REPO}"
releases="$(gh api "repos/${REPO}/releases" --paginate)"

# One version entry per release that ships an .ipa (newest first).
# md2txt turns the release-please Markdown changelog into clean plain text for AltStore's "What's New".
versions="$(echo "${releases}" | jq '
  def md2txt:
    (. // "")
    | gsub("\r"; "")
    | gsub("<!--[\\s\\S]*?-->"; "")                                   # HTML comments
    | gsub("##\\s*\\[[^\\]]+\\]\\([^)]+\\)\\s*\\([^)]+\\)"; "")        # "## [x.y.z](url) (date)" header
    | gsub("\\s*\\(\\[[0-9a-f]{6,}\\]\\([^)]+\\)\\)"; "")             # trailing ([hash](url))
    | gsub("\\[(?<t>[^\\]]+)\\]\\([^)]+\\)"; .t)                      # [text](url) -> text
    | gsub("\\*\\*"; "") | gsub("`"; "")                              # bold / code ticks
    | gsub("(?m)^#{1,6}\\s*"; "")                                     # heading markers
    | gsub("(?m)^\\s*Full Changelog.*$"; "")                         # GitHub auto footer
    | gsub("(?m)^[*-]\\s+"; "• ")                                     # bullets
    | gsub("\n{3,}"; "\n\n")
    | sub("^\\s+"; "") | sub("\\s+$"; "")
    | if . == "" then "Bug fixes and improvements." else . end;
  [ .[]
    | select(.draft == false)
    | . as $r
    | ($r.assets[] | select(.name | endswith(".ipa"))) as $ipa
    | {
        version: ($r.tag_name | ltrimstr("v")),
        date: ($r.published_at | split("T")[0]),
        localizedDescription: ($r.body | md2txt | .[0:1500]),
        downloadURL: $ipa.browser_download_url,
        size: $ipa.size,
        minOSVersion: "16.0"
      }
  ]')"

iphone_shots="$(shots_json iphone)"
ipad_shots="$(shots_json ipad)"

jq -n \
  --argjson versions "${versions}" \
  --argjson iphoneShots "${iphone_shots}" \
  --argjson ipadShots "${ipad_shots}" \
  --arg repo "${REPO}" \
  --arg icon "${ICONSET}" '
{
  name: "Dungeon Apps",
  subtitle: "Sideloadable apps for iPhone, iPad & Mac",
  website: "https://github.com/\($repo)",
  tintColor: "FF6500",
  iconURL: $icon,
  apps: [
    {
      name: "KinoPub",
      bundleIdentifier: "com.kino.pub",
      developerName: "dungeon-master-xx",
      subtitle: "Unofficial kino.pub client",
      localizedDescription: "Native iOS/iPadOS client for the kino.pub service: catalog, search by cast & crew, offline downloads, 4K/HDR, sport EPG and more. Community fork — not affiliated with kino.pub.",
      iconURL: $icon,
      tintColor: "FF6500",
      category: "entertainment",
      # Device-specific screenshots (newer AltStore/SideStore); screenshotURLs is the legacy fallback.
      screenshots: { iphone: $iphoneShots, ipad: $ipadShots },
      screenshotURLs: ($iphoneShots + $ipadShots),

      # Legacy AltStore fields (older AltStore reads these top-level keys; newer reads `versions`).
      version: ($versions[0].version // "1.0"),
      versionDate: ($versions[0].date // ""),
      versionDescription: ($versions[0].localizedDescription // ""),
      downloadURL: ($versions[0].downloadURL // ""),
      size: ($versions[0].size // 0),

      versions: $versions
    }
  ],
  news: []
}' > "${OUT}"

echo "✅ Wrote ${OUT} ($(echo "${versions}" | jq 'length') version(s))"
