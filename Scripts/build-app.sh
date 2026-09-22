#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/Lentera.app"

cd "$ROOT"
swift build -c release

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/Lentera" "$APP/Contents/MacOS/Lentera"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
VERSION="${LENTERA_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Support/Info.plist")}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
BUILD="${LENTERA_BUILD:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Support/Info.plist")}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
cp "$ROOT/Support/Lentera.icns" "$APP/Contents/Resources/Lentera.icns"
cp "$ROOT/Support/ThirdPartyNotices.txt" "$APP/Contents/Resources/ThirdPartyNotices.txt"
cp "$ROOT/Vendor/libgourou/LICENSE" "$APP/Contents/Resources/libgourou-LICENSE.txt"
rm -rf "$APP/Contents/Resources/Lentera_Lentera.bundle"
cp -R "$ROOT/.build/release/Lentera_Lentera.bundle" "$APP/Contents/Resources/"

BUNDLE="$APP/Contents/Resources/Lentera_Lentera.bundle"
LIB="$BUNDLE/lib"
mkdir -p "$LIB"

# Copy the engine's own dependencies, built with an older deployment target.
DEPS_LIB="$ROOT/.engine-deps/prefix/lib"
if [[ -d "$DEPS_LIB" ]]; then
  find "$DEPS_LIB" -maxdepth 1 -type f -name '*.dylib' -exec cp {} "$LIB/" \;
  if [[ -d "$DEPS_LIB/ossl-modules" ]]; then
    mkdir -p "$LIB/ossl-modules"
    cp "$DEPS_LIB"/ossl-modules/*.dylib(N) "$LIB/ossl-modules/"
  fi
fi

# Embed Sparkle so the app can install its own updates.
SPARKLE_SOURCE=$(find "$ROOT/.build/artifacts" -maxdepth 6 -type d -name Sparkle.framework -path '*macos-*' 2>/dev/null | head -n 1)
if [[ -n "$SPARKLE_SOURCE" ]]; then
  mkdir -p "$APP/Contents/Frameworks"
  ditto "$SPARKLE_SOURCE" "$APP/Contents/Frameworks/Sparkle.framework"
  # Lentera is not sandboxed, so Sparkle's XPC services are not needed.
  rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" \
         "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Lentera" 2>/dev/null || true
fi

codesign --force --sign - "$LIB"/*.dylib "$LIB"/ossl-modules/*.dylib(N) \
  "$BUNDLE"/acsmdownloader "$BUNDLE"/adept_activate "$BUNDLE"/adept_remove "$APP/Contents/MacOS/Lentera"
if [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
  SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign - "$SPARKLE/Versions/B/Autoupdate"
  codesign --force --sign - "$SPARKLE/Versions/B/Updater.app"
  codesign --force --sign - "$SPARKLE"
fi
codesign --force --sign - "$APP"

echo "Built $APP"
