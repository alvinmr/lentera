# Releasing Lentera

Maintainer notes. These steps use secrets. Only the repository owner has these secrets.

## Release flow

The repository uses [Release Please](https://github.com/googleapis/release-please). Release Please reads the Conventional Commits on `main`. The commit type sets the new version:

- `fix:` increases the patch version.
- `feat:` increases the minor version.
- `feat!:` or `BREAKING CHANGE:` increases the major version.

A push to `main` opens or updates a release pull request (PR). Merge the PR to create the tag and the GitHub Release.

Then the Release workflow builds the app on an Apple Silicon `macos-26` runner. The workflow uploads these items:

1. `Lentera-v<version>-macOS.dmg`
2. `appcast.xml`. The workflow signs this file with EdDSA. This file contains the release notes from the GitHub release.
3. The new version and the new checksum for the cask in `alvinmr/homebrew-tap`.

## One-time setup

### Sparkle signing key

```sh
Scripts/setup-sparkle.sh
```

The script does these steps:

1. It downloads the Sparkle tools into the `.sparkle-tools/` folder. Git ignores this folder.
2. It puts the EdDSA private key in the login Keychain.
3. It writes `SUPublicEDKey` into `Support/Info.plist`.
4. It sets the `SPARKLE_PRIVATE_KEY` secret.

Commit the change to `Support/Info.plist`. If you do not run this script, the releases continue. The Release workflow does not create the appcast. Therefore, automatic updates stop.

### Homebrew tap token

```sh
Scripts/setup-tap-token.sh
```

This script creates a fine-grained token for `alvinmr/homebrew-tap` with `Contents: Read and write`. It stores the token as `TAP_GITHUB_TOKEN`. If you do not run this script, the release does not update the cask. The workflow gives a warning.

### Release Please token (optional)

```sh
Scripts/setup-release-token.sh
```

This script creates a fine-grained token for this repository. The token has the `Contents`, `Pull requests`, and `Issues: Read and write` permissions. It stores the token as `RELEASE_PLEASE_TOKEN`. Pull requests with the default `GITHUB_TOKEN` do not start workflows. Therefore, release PRs skip CI (continuous integration) if you do not set this token. After you set this token, you can make the `test` check necessary on `main`.

## How to rebuild an existing release

Run **Actions > Release > Run workflow**:

- `release_tag`: the tag for the upload. Example: `v0.4.0`.
- `source_ref`: optional. The git ref for the build. The default value is the tag. Use `main` to include build fixes from commits after the tag.

The run replaces the DMG and creates a new appcast. The workflow run number supplies `CFBundleVersion`. Therefore, the installed apps can see the update.

## Repository requirements

- Enable GitHub Actions. Give the repository permission to create pull requests.
- Use the `macos-26` runner for the Liquid Glass SDK. The deployment target must stay macOS 14 in `Package.swift` and `Support/Info.plist`.
- The engine dependencies build from the source with `MACOSX_DEPLOYMENT_TARGET=14.0`. The build caches them in `.engine-deps`. The cache key is the hash of `Scripts/build-engine-deps.sh`. The build does not use Homebrew libraries. Therefore, the bundled tools operate on macOS versions that are older than the runner.
- The "Protect main" ruleset prevents force pushes and deletions. Do not make the status checks necessary until release PRs start CI.

## Secrets

| Secret | Purpose | Required |
| --- | --- | --- |
| `SPARKLE_PRIVATE_KEY` | Sign appcasts | Yes, for automatic updates |
| `TAP_GITHUB_TOKEN` | Update the Homebrew cask | Optional |
| `RELEASE_PLEASE_TOKEN` | Start CI on release PRs | Optional |
