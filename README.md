# Lentera

Lentera is a native macOS app for converting Adobe ACSM license files into the EPUB or PDF file returned by the authorized book provider. Conversion happens locally through the bundled libgourou tools, and completed books appear in a local bookshelf.

## Download

Download the latest `Lentera-<version>-macOS.zip` from the [GitHub Releases](https://github.com/alvinmr/lentera/releases) page, unzip it, and move `Lentera.app` to `/Applications`.

The release requires **Apple Silicon (M1 or later), macOS 14+**, and an internet connection for fulfillment. Intel Macs are not supported by this binary.

The app is ad-hoc signed and is **not Apple-notarized**. If macOS blocks it, attempt to open it once, then use **System Settings > Privacy & Security > Open Anyway** if you trust this download. Lentera does not require Homebrew or a separate runtime when using the release build.

## Use

1. Open Lentera and choose **Konversi**.
2. Click **Pilih File…**, or drag an `.acsm` file into the drop area.
3. Choose a destination folder if `Downloads` is not suitable.
4. Click **Konversi**. The provider determines whether the returned file is EPUB or PDF.
5. Open **Rak Buku** to find completed books. Click a book to reveal its file in Finder.

Lentera needs an ACSM file for a book you are authorized to access. An ACSM file is a license message, not the book itself; the provider and Adobe services still need to fulfill the license during conversion.

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

The build script bundles the required dynamic libraries, embeds the Lentera app icon, and ad-hoc signs the resulting app for local use.

## Automated Releases

Releases are managed by GitHub Actions with [Release Please](https://github.com/googleapis/release-please). Use Conventional Commit prefixes when committing to `main`:

- `fix:` increments the patch version (`0.1.0` → `0.1.1`)
- `feat:` increments the minor version (`0.1.0` → `0.2.0`)
- `feat!:` or `BREAKING CHANGE:` increments the major version (`0.1.0` → `1.0.0`)

A push to `main` opens or updates a release PR. Merge that PR to create the tag and GitHub Release. The release workflow then builds the app on `macos-14`, packages `Lentera.app`, and uploads the versioned ZIP automatically.

The workflow expects the repository's default `GITHUB_TOKEN`; no personal token is required. For a release to work, the repository must have Actions enabled and the Homebrew dependencies listed above must remain available.

## Privacy

Book files are processed locally. Lentera contacts Adobe and the book provider only through libgourou to fulfill and download the ACSM license. The anonymous ADEPT device identity is stored at `~/Library/Application Support/Lentera/adept` so retries can use the same device.

## Third-party source

The matching libgourou and uPDFParser source and licenses are included under `Vendor/libgourou`. The release includes a source archive alongside the app.

## Legal

Use Lentera only for books you are authorized to access and where local law permits format shifting. libgourou is licensed under LGPL-3.0; distributions bundling it must include its license and corresponding source or a compliant source offer.
