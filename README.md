# Lentera

[![Release](https://img.shields.io/github/v/release/alvinmr/lentera)](https://github.com/alvinmr/lentera/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20Apple%20Silicon-blue)](https://github.com/alvinmr/lentera/releases/latest)
[![License: MIT](https://img.shields.io/github/license/alvinmr/lentera)](LICENSE)

Lentera is a native macOS app. It converts ACSM license files from Adobe into an EPUB file or a PDF file that the book provider supplies. Lentera is a local alternative to Adobe Digital Editions. You can read the books in the app that you usually use.

![Lentera with a batch of ACSM files in the conversion queue](docs/screenshots/queue.png)

## Features

- **Batch conversion**: Move one or many `.acsm` files into the drop area. Lentera converts the files in sequence. If the conversion of one file fails, Lentera continues with the other files.
- **EPUB or PDF**: The provider selects the format. Lentera saves each file with the correct title and the author of the book.
- **Local bookshelf**: The bookshelf shows the covers of the converted books. You can search, filter, and sort the books. You can open a book, show it in Finder, change its data, or move it to the Trash.
- **Missing file detection**: Lentera marks a book when its file moves or is absent. Then you can remove the book from the bookshelf.
- **Automatic updates**: Lentera uses [Sparkle](https://sparkle-project.org) to install updates.
- **Data privacy**: All conversions occur on your Mac. The libgourou tools in the app do the conversion. No book file goes to a third-party server.

![Lentera bookshelf with covers](docs/screenshots/bookshelf.png)

## Download

Download the latest `Lentera-v<version>-macOS.dmg` from the [GitHub Releases](https://github.com/alvinmr/lentera/releases) page. Then do these steps:

1. Open the DMG file.
2. Move `Lentera.app` to the `Applications` shortcut.
3. Eject the DMG file.
4. Open Lentera from Applications.

The release is for **Apple Silicon Macs (M1 or later), macOS 14 or later**. An internet connection is necessary to fulfill the license. This binary does not operate on Intel Macs.

The app has an ad-hoc signature. Apple did not notarize the app. If macOS blocks the app, open it one time. If you trust the download, go to **System Settings > Privacy & Security > Open Anyway**. Homebrew and a separate runtime program are not necessary for the release build.

You can also install the app with [Homebrew](https://brew.sh). Homebrew installs the app without the Gatekeeper prompt. Homebrew downloads do not have a quarantine attribute.

```sh
brew tap alvinmr/tap
brew install --cask lentera
```

## Use

1. Open Lentera.
2. Click **Convert**.
3. Click **Choose Files…**, or move one or more `.acsm` files into the drop area. If you double-click an `.acsm` file in Finder, Lentera opens and adds the file to the queue.
4. Select a destination folder if `Downloads` is not the correct folder.
5. Click **Convert**. Lentera converts the files in sequence. If the conversion of one file fails, Lentera continues with the other files. The provider selects EPUB or PDF for each file.
6. Open **Bookshelf** to find the converted books. Click a book to open it. Right-click a book for more options.

You must have an ACSM file for a book that you can legally access. An ACSM file is a license message. It is not the book. During conversion, the provider and the Adobe services must supply the license.

## Updates

Lentera uses [Sparkle](https://sparkle-project.org) to install updates. To get an update, click **Check for Updates…** in the application menu. Sparkle signs the updates and verifies them. The app has an ad-hoc signature. Therefore, macOS can ask you to confirm the app after an update.

## Build the app from source

### Requirements

- macOS 14 or later
- Xcode 26 or later with Swift 6.2 or later
- CMake for the engine dependencies
- A libgourou source checkout, if the included vendor checkout is not prepared

Install CMake:

```sh
brew install cmake
```

Build the conversion engine and the app:

```sh
Scripts/build-engine.sh /path/to/libgourou
Scripts/build-app.sh
open build/Lentera.app
```

`build-engine.sh` first builds OpenSSL, curl, libzip, and pugixml from source. It builds these libraries for a macOS 14 deployment target. The build caches the results in the `.engine-deps/` folder. Git ignores this folder. If you build the libraries against Homebrew bottles, the engine will use the macOS version of the build machine.

If the prepared `Vendor/libgourou` checkout is available, do not give the engine path:

```sh
Scripts/build-engine.sh
Scripts/build-app.sh
```

Run the tests with:

```sh
swift test
```

The build script also bundles the necessary dynamic libraries. It adds the Lentera app icon to the app. It signs the app with an ad-hoc signature for local use. Run `Scripts/build-dmg.sh` to create a compressed DMG in `build/`. The DMG has the version of the built app.

Maintainers can find the release steps in [docs/RELEASING.md](docs/RELEASING.md).

## Troubleshooting

- **"This ACSM file has expired."** ACSM files expire. Download a new copy from the book provider. Then try again.
- **"This ACSM was already opened with another device or account."** Fulfill the license with the same authorization as before, or download a new ACSM file from the provider.
- **"The Google Play device limit has been reached."** Remove an old device authorization in your Google Play Books settings. Then try again.
- **"The book provider is rate limiting requests."** Wait 5 to 15 minutes. Then try again.
- **The conversion is complete, but the file is not in the correct folder.** Lentera saves the file in the folder that **Save to** shows. The default folder is `Downloads`. The file has the title of the book. If a file with the same name is in the folder, Lentera adds ` 2`, ` 3`, and more to the name.
- **macOS says the app cannot be verified.** Open the app one time. Then allow it in **System Settings > Privacy & Security**. Apple did not notarize the app.
- **The app does not operate on Intel Macs.** The release binary is for Apple Silicon only. For other systems, build the app from the source.
- **Where is my data?** The anonymous Adobe device identity and the bookshelf metadata are in `~/Library/Application Support/Lentera`. If you remove the app and this folder, you remove all the data that Lentera stores.

## Privacy

Lentera processes book files on your Mac. Lentera uses libgourou to contact Adobe and the book provider. It does this to fulfill the ACSM license and to download the book. Lentera stores the anonymous device identity of the ADEPT system at `~/Library/Application Support/Lentera/adept`. Therefore, a subsequent attempt can use the same device.

## Third-party source

The repository includes the related libgourou and uPDFParser source and licenses in `Vendor/libgourou`.

## Legal

The source of the app has an MIT license. See `LICENSE`. The conversion engine uses libgourou, which has an LGPL-3.0 license. The vendored source and the license are in `Vendor/libgourou`. The license is also in the app bundle. Use Lentera only for books that you can legally access. Use it only when local law permits the change of the file format.
