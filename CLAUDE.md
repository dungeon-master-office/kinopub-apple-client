# CLAUDE.md

Guidance for working in this repo. It's a **community fork** of
[leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client): a native SwiftUI
client for the third-party **kino.pub** service, targeting **iOS/iPadOS 16+ and macOS 13+**
(no tvOS — the `AppleTV/` UI components are just tvOS-*style* cards). The app is distributed as an
**unsigned build** for sideloading (AltStore Classic / SideStore / Sideloadly / TrollStore) and a
macOS `.dmg`/`.app`; it authenticates against a user's own kino.pub account via the device-code flow
and bundles no credentials.

## Build & run

```bash
# iOS (compile check / run) — simulator name may vary by Xcode
xcodebuild -project KinoPubAppleClient.xcodeproj -scheme KinoPubAppleClient \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation build

# macOS (native) — ad-hoc signed
xcodebuild -project KinoPubAppleClient.xcodeproj -scheme KinoPubAppleClient \
  -configuration Release -destination 'platform=macOS' -skipPackagePluginValidation \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES DEVELOPMENT_TEAM="" build

./scripts/build-ipa.sh     # unsigned .ipa  -> dist/  (BUNDLE_ID=com.kino.pub … / BUILD_NUMBER=… to override)
./scripts/build-macos.sh   # .app + zip     -> dist/
./scripts/build-dmg.sh     # drag-to-install .dmg (+ Gatekeeper-fix .command) -> dist/
```

- **Signing:** `DEVELOPMENT_TEAM` is intentionally **empty** in the project. Pick your own team in
  Xcode locally; **never commit it** (a local `.git/hooks/pre-commit` blocks accidental team-id /
  custom-bundle-id leaks). Release artifacts are unsigned and re-signed by the sideloader.
- **Xcode 26** is required for the iOS 26 Liquid Glass icon (`AppIcon.icon`) and effects
  (`glassEffect`). Those APIs are compile-gated with `#if compiler(>=6.2)` + a material fallback so
  older Xcode still builds; the app also ships a classic `AppIcon.appiconset` for iOS < 26.

## Tests

Unit tests live in the SwiftPM packages and run fast with `swift test`:

```bash
cd Packages/KinoPubBackend && swift test          # models, decoding, WatchProgress (edge cases)
```

Prefer putting pure/business logic in `KinoPubBackend`/`KinoPubKit` so it's unit-testable via
`swift test` (the full app build is only needed for UI-level changes).

## CI & releases

Runners are **`macos-26` / Xcode 26** (so releases ship with Liquid Glass). Workflows:

- **CI** (`ci.yml`) — compile check on push to `main` + PRs (required status check `build`).
- **Lint** (`lint.yml`) — SwiftLint + swift-format, informational.
- **Release Please** (`release-please.yml`) — reads Conventional Commits, opens a "release PR"
  bumping `version.txt` + `CHANGELOG.md` (and the pbxproj `MARKETING_VERSION` via `extra-files`).
- **Release** (`release.yml`) — dispatched by Release Please; builds the IPA + macOS `.zip`/`.dmg`,
  regenerates the AltStore source, and attaches everything to the release.
- **Pages** (`pages.yml`) — deploys `docs/` (landing page) on push to `main`.

**Release flow (use PRs; `main` is protected):**
1. Land work via a PR into `main` (**Conventional Commits** drive the version bump: `feat:` → minor,
   `fix:` → patch, `feat!:`/`BREAKING CHANGE` → major; `chore/ci/docs/refactor/perf` don't release).
2. Merge the auto-opened **Release Please** PR → tags + release + build → artifacts attached.

Notes: the build workflows select the newest Xcode (`Xcode_26*`). CodeQL was removed (too slow).

## Architecture

Swift Package Manager workspace:

| Package | Purpose |
|---|---|
| `KinoPubAppleClient` | App target (views, services, app state), shared across platforms |
| `KinoPubUI` | Reusable SwiftUI components (`MediaShelf`, cards, `ContentItemsListView`, colors) |
| `KinoPubKit` | Shared business logic |
| `KinoPubBackend` | Networking layer + models (kino.pub API) |
| `KinoPubLogging` | OSLog helpers |

Key pieces:

- **`WatchProgress`** (`KinoPubBackend`) — the single source of truth for watch state:
  `fraction` + `state` (`unwatched`/`inProgress`/`finished`), with the end-of-credits tolerance in
  one place (8% of runtime, 60–180 s, capped at half). Everything classifies through it:
  `Episode/Video.isWatched` (server flag **or** watched-to-credits), Continue Watching, the card
  badge, the season list, and the local/library progress stores. **Don't re-derive watched/progress
  with ad-hoc thresholds — route through `WatchProgress`.**
- **kino.pub watch sync is automatic**: the player reports position via `/v1/watching/marktime`
  (every 10 s + a final marktime at full duration on play-to-end). The server derives "watched"
  from the reported position — there is **no "set watched" call** (`/watching/toggle` only *flips*,
  so don't call it on a normal finish). Finished titles are filtered out of Continue Watching client-side.
- **`MediaLibraryStore`** — optimistic client state (bookmarks/watchlist/watched overrides,
  downloads/progress façade) reconciled against the server. **`LocalWatchProgressStore`** — local
  resume points so Continue Watching updates instantly (its "started" floor = `WatchProgress.startedSeconds`).
- **HDR/4K:** driven by the device profile advertising HEVC + 4K + `mixedPlaylist`; AVPlayer renders
  HDR10 natively. Verify on a real HDR device (Simulator can't).
- **Sport EPG** (`Views/Sport/` + `Services/EPG/`) — the Sport tab is an Electronic Program Guide:
  inline player pinned on top + a channel list whose rows show now/next. `EPGServiceImpl` (an `actor`)
  SAX-parses (low-memory) the XMLTV feeds configured in `Resources/EPGSources.json` — each source has a
  `url`, `cacheHours`, and a `map` — merging them per channel (**first source with data wins**) and
  caching each to disk with its own TTL. Channel matching is the explicit `map` override (kino.pub
  title → feed `<channel id>`, which may be Cyrillic, e.g. `"МАТЧ! ТВ": "Матч!"`) then a normalized-name
  fallback (lowercase, ё→е, drop `tv/тв/hd/…`). These feeds are **per-country and can be huge** (iptv-
  epg.org's US feed is 12k+ channels / >40 MB gz), so keep sources targeted; add sources/channels by
  editing `EPGSources.json` — no code change. `EPGServiceImpl.diskUsageBytes()` / `clearCache()` back
  the EPG row in the Storage screen.
- **kino.pub API request encoding (subtle — verify new endpoints live before wiring UI):** write
  mutations read params from the **form body**, not the query. `POST /v1/bookmarks/{toggle-item,create,
  remove-folder}` set `forceSendAsGetParams = false`; sent as query params they silently `404`/`400`/
  no-op (this is why bookmarks once "only worked client-side"). Exceptions that *do* read the query:
  `POST /v1/history/clear-for-*`, and every GET call (vote, `watching/toggle`, `marktime`). Response
  quirks: `watching/toggle` returns `watching` as an **object** `{status}` (not a `Bool`), and
  `history/clear-*` returns a literal `null` — so `EmptyResponseData` tolerates null/empty bodies.
- **Detail-screen data has three sources.** (1) The kino.pub item (`/v1/items/<id>`) — base fields +
  its **own rating** (`rating_percentage`/10 with `rating_votes`) + like/dislike via
  `GET /v1/items/vote?id=&like=1|0` (a **one-time** vote, *not* a toggle, with no read-back, so the
  user's choice is remembered locally in `MediaLibraryStore.userVotes`). (2) **Cast/crew photos** from
  kino.pub's CDN `m.pushbr.com/actors/<md5(russian name)>.jpg` (TMDB was fully removed — no API key).
  (3) **Facts / reviews / full crew-with-characters / stills** aren't in the kino.pub API at all — they
  come from the **kpapp.link "kpapi" proxy** over Kinopoisk (`kpapp.link/kpapi/films/<kinopoisk id>/
  {facts,reviews,staff,images}`, public, no key), keyed by `mediaItem.kinopoisk`; see
  `KinopoiskExtras.swift`. That proxy is a third-party dependency — each section degrades to hidden if it
  fails. `/v1/items` filtering only honors type/genre/country/year/sort **plus `director=`/`cast=`**;
  rating/HD/4K/AC3 are applied client-side.

## Conventions

- **Dark-only app:** the root pins `.preferredColorScheme(.dark)` (the color assets' light appearance
  is inconsistent). macOS quits when its window closes; auth is full-window on macOS (not a modal
  sheet, which would disable the window's close button).
- **Lazy stacks** in every `ScrollView` (`LazyHStack`/`LazyVStack`/`LazyVGrid`) — small fixed chip
  bars stay eager.
- **3D playback** is behind `FeatureFlags.threeDEnabled` (off) — `AVVideoComposition` doesn't apply
  to HLS streams.
- Adding a Swift file to the **app target** (or a bundled resource) needs a pbxproj entry; package
  files auto-include. Without opening Xcode, register them with the `xcodeproj` ruby gem
  (`gem install --user-install xcodeproj`): add a file reference to the matching group + a build file
  to the target's Sources phase (resources go in the resources phase).
- **`Localizable.xcstrings`** is a key-sorted JSON catalog. Edit it programmatically — e.g. Python
  `json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True)` round-trips it byte-identically, so
  new keys land as a minimal diff. `"key".localized` falls back to the key text when a string is
  missing, so it's safe to add call-site strings and catalog keys in separate steps.

## Distribution

- **AltStore source** (`Dungeon Apps`) is generated per release by `scripts/gen-altstore-source.sh`
  and published as a release asset, so `…/releases/latest/download/apps.json` always serves the
  newest. Deep links use the **`altstore-classic://`** scheme (AltStore PAL is notarized-only and
  can't install this).
- Install guide, FAQ, and one-tap buttons live in the **Wiki** and the **Pages landing** (`docs/`).
