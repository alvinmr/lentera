# Releasing Lentera

Maintainer notes. Only the repository owner has the secrets these steps rely on.

## Release flow

- Conventional Commits on `main` drive [Release Please](https://github.com/googleapis/release-please):
  `fix:` bumps the patch version, `feat:` the minor, `feat!:` or `BREAKING CHANGE:` the major.
- A push to `main` opens or updates a release PR. Merge it to create the tag and GitHub Release.
- The Release workflow then builds on an Apple Silicon `macos-26` runner and uploads:
  - `Lentera-v<version>-macOS.dmg`
  - `appcast.xml`, signed with EdDSA and with the release notes embedded from the GitHub release body
  - a version and checksum bump for the cask in `alvinmr/homebrew-tap`

## One-time setup

### Sparkle signing key

```sh
Scripts/setup-sparkle.sh
```

The wizard downloads Sparkle's tools into `.sparkle-tools/` (git-ignored), stores the EdDSA
private key in the login Keychain, writes `SUPublicEDKey` into `Support/Info.plist` (commit that
change), and sets the `SPARKLE_PRIVATE_KEY` secret. Without it, releases still publish but the
appcast is skipped and auto-updates stop working.

### Homebrew tap token

```sh
Scripts/setup-tap-token.sh
```

Creates a fine-grained token scoped to `alvinmr/homebrew-tap` with `Contents: Read and write` and
stores it as `TAP_GITHUB_TOKEN`. Without it, releases skip the cask bump with a warning.

### Release Please token (optional)

```sh
Scripts/setup-release-token.sh
```

Creates a fine-grained token scoped to this repository with `Contents`, `Pull requests`, and
`Issues: Read and write`, stored as `RELEASE_PLEASE_TOKEN`. Pull requests opened with the default
`GITHUB_TOKEN` do not trigger workflows, so release PRs skip CI without it. Once this is set, the
`test` check can be required on `main`.

## Rebuilding an existing release

Run **Actions > Release > Run workflow**:

- `release_tag`: the tag to upload to, for example `v0.4.0`.
- `source_ref`: optional git ref to build from; defaults to the tag. Use `main` to ship build fixes
  that landed after the tag.

The run replaces the DMG and regenerates the appcast. `CFBundleVersion` comes from the workflow run
number, so installed apps still see the update.

## Repository requirements

- Actions enabled, with permission to create pull requests.
- Runner `macos-26` for the Liquid Glass SDK; the deployment target stays macOS 14 in `Package.swift`
  and `Support/Info.plist`.
- Engine dependencies build from source with `MACOSX_DEPLOYMENT_TARGET=14.0` and are cached in
  `.engine-deps` (cache key = hash of `Scripts/build-engine-deps.sh`). Homebrew libraries are not
  used, so the bundled tools keep running on older macOS than the runner.
- The "Protect main" ruleset blocks force pushes and deletions. Required status checks are left off
  until release PRs run CI.

## Secrets

| Secret | Purpose | Required |
| --- | --- | --- |
| `SPARKLE_PRIVATE_KEY` | Sign appcasts | Yes, for auto-updates |
| `TAP_GITHUB_TOKEN` | Bump the Homebrew cask | Optional |
| `RELEASE_PLEASE_TOKEN` | Run CI on release PRs | Optional |
