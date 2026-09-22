# Lentera

Lentera is a native macOS app for converting Adobe ACSM license files into the EPUB or PDF file returned by the authorized book provider. Conversion happens locally through the bundled libgourou tools, and completed books appear in a local bookshelf.

## Download

Download the latest `Lentera-v<version>-macOS.dmg` from the [GitHub Releases](https://github.com/alvinmr/lentera/releases) page. Open it, drag `Lentera.app` onto the `Applications` shortcut, then eject the disk image and launch Lentera from Applications. A ZIP download is also available.

The release requires **Apple Silicon (M1 or later), macOS 14+**, and an internet connection for fulfillment. Intel Macs are not supported by this binary.

The app is ad-hoc signed and is **not Apple-notarized**. If macOS blocks it, attempt to open it once, then use **System Settings > Privacy & Security > Open Anyway** if you trust this download. Lentera does not require Homebrew or a separate runtime when using the release build.

## Use

1. Open Lentera and choose **Convert**.
2. Click **Choose Files…**, or drag one or more `.acsm` files into the drop area. Double-clicking an `.acsm` file in Finder opens Lentera and adds it to the queue.
3. Choose a destination folder if `Downloads` is not suitable.
4. Click **Convert**. Files are converted one at a time; a failed book does not stop the rest of the queue. The provider determines whether each returned file is EPUB or PDF.
5. Open **Bookshelf** to find completed books. Click a book to reveal its file in Finder.

Lentera needs an ACSM file for a book you are authorized to access. An ACSM file is a license message, not the book itself; the provider and Adobe services still need to fulfill the license during conversion.

## Updates

Lentera updates itself with [Sparkle](https://sparkle-project.org). Release builds embed a signed appcast, so installed apps can use **Check for Updates…** from the application menu. Sparkle validates each update with the EdDSA signature, so an Apple Developer ID certificate is not required; the app is ad-hoc signed, and macOS may occasionally ask you to confirm opening Lentera after an update.

Maintainers must create the Sparkle signing key once before publishing a release:

```sh
Scripts/setup-sparkle.sh
```

The wizard downloads Sparkle's tools into `.sparkle-tools/` (git-ignored), stores the private key in your login Keychain, writes `SUPublicEDKey` into `Support/Info.plist`, and sets the `SPARKLE_PRIVATE_KEY` GitHub Actions secret. Commit the Info.plist change. Each release then publishes a signed `appcast.xml` that the app reads from `https://github.com/alvinmr/lentera/releases/latest/download/appcast.xml`.

## Build From Source

### Requirements

- macOS 14 or later
- Xcode 26 or later with Swift 6.2+
- Homebrew dependencies: `curl`, `libzip`, `openssl@3`, and `pugixml`
- A libgourou source checkout, unless the included vendor checkout is already prepared

Install the native dependencies:

```sh
brew install curl libzip openssl@3 pugixml
```

Build the conversion engine and the app:

```sh
Scripts/build-engine.sh /path/to/libgourou
Scripts/build-app.sh
open build/Lentera.app
```

If you are using the prepared `Vendor/libgourou` checkout, omit the engine path:

```sh
Scripts/build-engine.sh
Scripts/build-app.sh
```

Run the tests with:

```sh
swift test
```

The build script bundles the required dynamic libraries, embeds the Lentera app icon, and ad-hoc signs the resulting app for local use. Run `Scripts/build-dmg.sh` afterward to create a compressed DMG in `build/`; its version comes from the built app.

## Automated Releases

Releases are managed by GitHub Actions with [Release Please](https://github.com/googleapis/release-please). Use Conventional Commit prefixes when committing to `main`:

- `fix:` increments the patch version (`0.1.0` → `0.1.1`)
- `feat:` increments the minor version (`0.1.0` → `0.2.0`)
- `feat!:` or `BREAKING CHANGE:` increments the major version (`0.1.0` → `1.0.0`)

A push to `main` opens or updates a release PR. Merge that PR to create the tag and GitHub Release. A dependent job in the same workflow then builds the app on an Apple Silicon `macos-15` runner, packages `Lentera.app`, and uploads the versioned DMG and ZIP automatically.

The workflow expects the repository's default `GITHUB_TOKEN`; no personal token is required. For a release to work, the repository must have Actions enabled and the Homebrew dependencies listed above must remain available.

You can also run **Actions > Release > Run workflow** to verify a build without publishing a new version. The DMG and ZIP are available as workflow artifacts. GitHub Actions must be allowed to create pull requests under **Settings > Actions > General > Workflow permissions**.

## Privacy

Book files are processed locally. Lentera contacts Adobe and the book provider only through libgourou to fulfill and download the ACSM license. The anonymous ADEPT device identity is stored at `~/Library/Application Support/Lentera/adept` so retries can use the same device.

## Third-party source

The matching libgourou and uPDFParser source and licenses are included under `Vendor/libgourou` in the repository.

## Legal

Use Lentera only for books you are authorized to access and where local law permits format shifting. libgourou is licensed under LGPL-3.0; distributions bundling it must include its license and corresponding source or a compliant source offer.
