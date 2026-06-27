# Contributing

Thanks for your interest in improving this client! This is a community-maintained fork — issues and
pull requests are welcome.

## Getting started

1. **Fork** the repo and clone your fork.
2. Open `KinoPubAppleClient.xcodeproj` in **Xcode 16+** (the project targets iOS/iPadOS 16+ and macOS 13+).
3. In **Signing & Capabilities**, select your own team. `DEVELOPMENT_TEAM` is intentionally empty in the
   repo — **don't commit your team id**.
4. Build & run on a simulator, device, or My Mac.

## Branching & commits

- Branch off `main`.
- We use **[Conventional Commits](https://www.conventionalcommits.org/)** — this drives automatic
  SemVer versioning and the changelog via Release Please:
  - `feat: …` → minor bump
  - `fix: …` → patch bump
  - `feat!: …` / `fix!: …` or a `BREAKING CHANGE:` footer → major bump
  - `docs:`, `refactor:`, `perf:`, `chore:`, `ci:`, `test:` — no release on their own
- Keep PRs focused. Fill in the PR template.

## Checks

- **CI** builds the app for iOS on every PR (required to merge).
- **Lint** runs SwiftLint + swift-format and reports as annotations (informational, not blocking).
  Run them locally before pushing:
  ```bash
  swiftlint
  swift format lint --recursive .
  ```

## Releases

You don't tag manually. Merging conventional commits to `main` makes **Release Please** open a release
PR that bumps `version.txt` and `CHANGELOG.md`. Merging that PR cuts the tag + GitHub Release, and the
**Release** workflow builds and attaches the unsigned IPA automatically.

## Code of Conduct

By participating you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).
