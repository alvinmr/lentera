#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/Lentera.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$' ]] || { echo "Invalid app version" >&2; exit 1; }
codesign --verify --deep --strict "$APP"

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Lentera.app"
ln -s /Applications "$STAGING/Applications"
DMG="$ROOT/build/Lentera-v${VERSION}-macOS.dmg"
hdiutil create -volname Lentera -srcfolder "$STAGING" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"
echo "Built $DMG"
