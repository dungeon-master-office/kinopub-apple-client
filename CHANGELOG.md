# Changelog

## [1.5.1](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.5.0...v1.5.1) (2026-07-02)


### 📝 Docs

* add CLAUDE.md dev/architecture guide ([#24](https://github.com/dungeon-master-xx/kinopub-apple-client/issues/24)) ([d60388a](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/d60388a5d3b73fd7ce2ed1880291d1cadbeda2a9))

## [1.5.0](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.4.2...v1.5.0) (2026-06-28)


### ✨ Features

* Continue Watching polish + unified watch-status (tested) + lazy lists ([16763d4](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/16763d481c18c550666f3d5611c1122a6953d3a3))

## [1.4.2](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.4.1...v1.4.2) (2026-06-28)


### 📝 Docs

* AltStore button uses altstore-classic:// scheme (avoid AltStore PAL) ([#20](https://github.com/dungeon-master-xx/kinopub-apple-client/issues/20)) ([2b90eab](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/2b90eabc44fc834ce78d90d5cc91d4e6a1feec06))

## [1.4.1](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.4.0...v1.4.1) (2026-06-28)


### 🐛 Fixes

* stop advertising 3D video in the README (it's disabled behind a flag) ([#18](https://github.com/dungeon-master-xx/kinopub-apple-client/issues/18)) ([500c50a](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/500c50a77577adea4fd805d572fae5acaf2e81f4))

## [1.4.0](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.3.0...v1.4.0) (2026-06-28)


### ✨ Features

* **altstore:** richer source metadata ([#15](https://github.com/dungeon-master-xx/kinopub-apple-client/issues/15)) ([1bd4c86](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/1bd4c86333096d7b31f194a39c2a208dc8d352aa))


### 🐛 Fixes

* **altstore:** declare screenshot width/height (AltStore requires size for iPad) ([#13](https://github.com/dungeon-master-xx/kinopub-apple-client/issues/13)) ([e00065d](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/e00065d9a3ab8bf3a707b497aec23a82dfd51467))

## [1.3.0](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.2.0...v1.3.0) (2026-06-28)


### ✨ Features

* macOS fixes, DMG installer, rename to dungeon-master-xx, device screenshots ([7b3377a](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/7b3377a774c8e4bd250a4e135dd3fa5beed0804f))

## [1.2.0](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.1.1...v1.2.0) (2026-06-27)


### ✨ Features

* AltStore/SideStore source for one-tap install + auto-updates ([d302bc4](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/d302bc49a39e82ad76dedf01aae4a86539d821ba))
* GitHub Pages redirector for one-tap AltStore/SideStore source links ([ec616da](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/ec616da6e52e052630395ad8307733fda4e0275a))
* **settings:** add About section (source code, report a problem, install guide) ([b3771e2](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/b3771e250f6abbaf426d40c200759318988bb2b3))


### 🐛 Fixes

* **altstore:** include legacy source fields for older AltStore compatibility ([f3a1a7b](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/f3a1a7ba7c4bab0e6428c415d0f8a1b4f1155f98))
* render clean plain-text What's New in AltStore source (strip Markdown) ([e76b783](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/e76b783c9e68ecab5809e640a434eab9f51721dc))
* sync app version across project, settings and releases ([d2d947c](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/d2d947ca0035eab8e3748072050b1426512c9a98))


### 📝 Docs

* AltStore/SideStore install banner with badges in README ([dc7c8aa](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/dc7c8aadd33d99760b8f2ff6fc1bfff2dba749de))
* landing page with AltStore/SideStore buttons + screenshots ([099f3e5](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/099f3e5a6254eaef01e59f1536c40b24bb078cbd))
* top AltStore version badge + use self-hosted Pages redirector for source buttons ([40aba5a](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/40aba5aa7fadac0f2635d9f150b1405db0e8ba8f))

## [1.1.1](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.1.0...v1.1.1) (2026-06-27)


### 🐛 Fixes

* **macos:** add macOS app icon (idiom: mac) so the .app isn't blank ([dde14d4](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/dde14d4b0d425bae0ccd70aec3f78707471b3494))

## [1.1.0](https://github.com/dungeon-master-xx/kinopub-apple-client/compare/v1.0.0...v1.1.0) (2026-06-27)


### ✨ Features

* playback, search, collections & cross-platform (macOS/iPad) improvements ([9a25b0c](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/9a25b0c1c4adb5bd18edf573428165c618217f9f))
* **release:** build & attach macOS app artifact ([a19ceec](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/a19ceec44d54f2ec2d77814a800af1934e12a701))


### 📝 Docs

* add app screenshots gallery to README; bump actions/checkout to v5 ([f1a82de](https://github.com/dungeon-master-xx/kinopub-apple-client/commit/f1a82decf0427eef0c4997713dd7ae09c8dc47ed))
