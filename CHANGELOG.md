# Changelog

## [1.2.0](https://github.com/alvinmr/lentera/compare/v1.1.0...v1.2.0) (2026-09-23)


### Features

* export, import, and reset the Adobe activation in Settings ([3c16114](https://github.com/alvinmr/lentera/commit/3c161147678d04c1a95d53734b4bdaf1ae238fcf))
* redesign Edit Details, show ACSM details in the queue, back up the Adobe activation ([77747a9](https://github.com/alvinmr/lentera/commit/77747a9801ee9070d09676e9dac64f8f89bd9833))
* redesign the Edit Details sheet ([3c16114](https://github.com/alvinmr/lentera/commit/3c161147678d04c1a95d53734b4bdaf1ae238fcf))
* show the title, author, format, and expiration from the ACSM in the queue ([3c16114](https://github.com/alvinmr/lentera/commit/3c161147678d04c1a95d53734b4bdaf1ae238fcf))


### Bug Fixes

* address review findings on activation import, expiry, and covers ([66115a9](https://github.com/alvinmr/lentera/commit/66115a9fa43a216f2aea7ac44eaf79c91f7c9573))
* keep line breaks from titles out of file names ([b51bf74](https://github.com/alvinmr/lentera/commit/b51bf747cec2c14c1fd0979b888cd34ba4a2ea5e))
* keep the ACSM fingerprint when a book is edited ([3c16114](https://github.com/alvinmr/lentera/commit/3c161147678d04c1a95d53734b4bdaf1ae238fcf))


### Performance Improvements

* load shelf covers in the background and cache them in memory ([3c16114](https://github.com/alvinmr/lentera/commit/3c161147678d04c1a95d53734b4bdaf1ae238fcf))

## [1.1.0](https://github.com/alvinmr/lentera/compare/v1.0.1...v1.1.0) (2026-09-23)


### Features

* add Send to Kindle, a wooden bookshelf, and motion ([2ab2202](https://github.com/alvinmr/lentera/commit/2ab2202e2ae8ea86e3d4a02fc9ba87764d2a5e25))
* add shared motion tokens ([a2a2870](https://github.com/alvinmr/lentera/commit/a2a2870191e4bc6cb9ed94bb497aa267e3ab276a))
* animate removing books from the shelf ([bd61615](https://github.com/alvinmr/lentera/commit/bd61615a13fcf2db6ca8d13ebc0629443300fba1))
* animate the conversion queue and status ([dd60ceb](https://github.com/alvinmr/lentera/commit/dd60ceb8b69e108da41f9f01767658e8bd188275))
* land new books on the shelf ([af3e185](https://github.com/alvinmr/lentera/commit/af3e18562f3e82e5fdaa90c70e3189b02fda664d))
* send a book to Kindle from the bookshelf ([6fbda17](https://github.com/alvinmr/lentera/commit/6fbda178bb9216f79f2b7f6fea02acd1f2bb9fda))
* show the bookshelf as wooden shelves ([e235b0d](https://github.com/alvinmr/lentera/commit/e235b0dcff0814465acd2923b6396e96af9ebc47))


### Bug Fixes

* make the book hover lift subtler ([bb0d46e](https://github.com/alvinmr/lentera/commit/bb0d46e493ae833fe30702bba63e704024ddd2cf))

## [1.0.1](https://github.com/alvinmr/lentera/compare/v1.0.0...v1.0.1) (2026-09-22)


### Bug Fixes

* load the OpenSSL legacy provider from the app bundle ([816e74d](https://github.com/alvinmr/lentera/commit/816e74d6642114e6dd400029b6d08d326ebe0816))

## [1.0.0](https://github.com/alvinmr/lentera/compare/v0.5.0...v1.0.0) (2026-09-22)


### Features

* add a Settings window ([159d492](https://github.com/alvinmr/lentera/commit/159d492e375d8eb1edaeee7e59be1dafc6bbd632))
* log conversions and batch outcomes ([d76652e](https://github.com/alvinmr/lentera/commit/d76652e09062847d9c79611f4574b83ed917422b))
* notify when a batch finishes ([866e88c](https://github.com/alvinmr/lentera/commit/866e88c79bba95aad6a95d57e29034fc350d8a7e))
* render PDF covers ([5971aad](https://github.com/alvinmr/lentera/commit/5971aad42a10e19bfb6632d4ca07ef94ab0687d8))
* retry failed queue items ([16aac30](https://github.com/alvinmr/lentera/commit/16aac30834321bc033aef2f3d596e003e8f06c1c))
* skip ACSM files that were already converted ([122ebeb](https://github.com/alvinmr/lentera/commit/122ebeb46187060ca7f75903d5bbef988eb34ba0))


### Miscellaneous Chores

* target the 1.0.0 release ([8821238](https://github.com/alvinmr/lentera/commit/8821238b41bc483a3c82ef223df0f768f235b09d))

## [0.5.0](https://github.com/alvinmr/lentera/compare/v0.4.0...v0.5.0) (2026-09-22)


### Features

* add a Help menu with docs and release notes links ([e4621e5](https://github.com/alvinmr/lentera/commit/e4621e58a894d063f5c9fc010b6140d2b5f27592))

## [0.4.0](https://github.com/alvinmr/lentera/compare/v0.3.0...v0.4.0) (2026-09-22)


### Features

* adopt Liquid Glass surfaces ([a9596e6](https://github.com/alvinmr/lentera/commit/a9596e647afdf98ed97f3f3729f629080ef08b99))

## [0.3.0](https://github.com/alvinmr/lentera/compare/v0.2.1...v0.3.0) (2026-09-22)


### Features

* add Sparkle auto-updates ([e300bc6](https://github.com/alvinmr/lentera/commit/e300bc6150bc22979e92092accbe37771745cac1))
* manage bookshelf entries ([ab12052](https://github.com/alvinmr/lentera/commit/ab12052ec579c085cd962be0ec825fdaeec7aa0b))
* support batch conversion and Finder file opens ([f1cb4bb](https://github.com/alvinmr/lentera/commit/f1cb4bbb380d40120f10b5f37b4871ad67fb9a39))
* translate the app interface to English ([73b9826](https://github.com/alvinmr/lentera/commit/73b98269f7ad250148e247bb9e3d89ab628c0e9b))


### Bug Fixes

* include macOS DMG installer in releases ([688ef69](https://github.com/alvinmr/lentera/commit/688ef690e3ad5681aee5378caabfac7563b66217))

## [0.2.1](https://github.com/alvinmr/lentera/compare/v0.2.0...v0.2.1) (2026-09-22)


### Bug Fixes

* recover invalid EPUB cover cache ([c2b99e9](https://github.com/alvinmr/lentera/commit/c2b99e9799c924daae30d7d3914eb09d81f2375f))

## [0.2.0](https://github.com/alvinmr/lentera/compare/v0.1.0...v0.2.0) (2026-09-21)


### Features

* improve bookshelf and conversion reliability ([1ba5be2](https://github.com/alvinmr/lentera/commit/1ba5be29f3308829ea9870dd5be4875d0d792ee5))
