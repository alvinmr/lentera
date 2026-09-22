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
cp -R "$ROOT/.build/release/Lentera_Lentera.bundle" "$APP/Contents/Resources/"

BUNDLE="$APP/Contents/Resources/Lentera_Lentera.bundle"
LIB="$BUNDLE/lib"
mkdir -p "$LIB"

# Bundle every Homebrew dylib needed by libgourou so end users do not need Homebrew.
typeset -a queue
queue=("$BUNDLE"/acsmdownloader "$BUNDLE"/adept_activate "$BUNDLE"/adept_remove)
typeset -A seen
while (( ${#queue[@]} )); do
  binary="${queue[1]}"
  queue=("${queue[@]:1}")
  while IFS= read -r dependency; do
    [[ "$dependency" == /opt/homebrew/* ]] || continue
    name="${dependency:t}"
    bundled="$LIB/$name"
    if [[ -z "${seen[$dependency]-}" ]]; then
      cp -L "$dependency" "$bundled"
      chmod u+w "$bundled"
      install_name_tool -id "@loader_path/$name" "$bundled"
      seen[$dependency]=1
      queue+=("$bundled")
    fi
    if [[ "$binary" == "$LIB"/* ]]; then
      replacement="@loader_path/$name"
    else
      replacement="@loader_path/lib/$name"
    fi
    install_name_tool -change "$dependency" "$replacement" "$binary"
  done < <(otool -L "$binary" | tail -n +2 | awk '{print $1}')
done

# Some Homebrew libraries use @rpath for one small transitive dependency.
if [[ -f /opt/homebrew/opt/brotli/lib/libbrotlicommon.1.dylib ]]; then
  cp -L /opt/homebrew/opt/brotli/lib/libbrotlicommon.1.dylib "$LIB/libbrotlicommon.1.dylib"
  chmod u+w "$LIB/libbrotlicommon.1.dylib"
  install_name_tool -id '@loader_path/libbrotlicommon.1.dylib' "$LIB/libbrotlicommon.1.dylib"
  install_name_tool -change '@rpath/libbrotlicommon.1.dylib' '@loader_path/libbrotlicommon.1.dylib' "$LIB/libbrotlidec.1.dylib"
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

codesign --force --sign - "$LIB"/* "$BUNDLE"/acsmdownloader "$BUNDLE"/adept_activate "$BUNDLE"/adept_remove "$APP/Contents/MacOS/Lentera"
if [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
  SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign - "$SPARKLE/Versions/B/Autoupdate"
  codesign --force --sign - "$SPARKLE/Versions/B/Updater.app"
  codesign --force --sign - "$SPARKLE"
fi
codesign --force --sign - "$APP"

echo "Built $APP"
