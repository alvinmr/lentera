#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE="${1:-$ROOT/Vendor/libgourou}"
DEST="$ROOT/Sources/Lentera/Resources/tools"

if [[ ! -d "$SOURCE" ]]; then
  echo "libgourou source not found at $SOURCE"
  echo "Pass its path: Scripts/build-engine.sh /path/to/libgourou"
  exit 1
fi

export PATH="/opt/homebrew/opt/openssl@3/bin:/opt/homebrew/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/include -I/opt/homebrew/opt/openssl@3/include"
export LDFLAGS="-L/opt/homebrew/lib -L/opt/homebrew/opt/openssl@3/lib"
export CXX="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
export AR="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

make -C "$SOURCE/lib/updfparser" clean all BUILD_STATIC=1 BUILD_SHARED=0 CXX="$CXX" AR="$AR" \
  CXXFLAGS="-Wall -fPIC -O2 -isysroot $SDKROOT -I./include"
make -C "$SOURCE" clean all BUILD_STATIC=1 BUILD_SHARED=0 STATIC_UTILS=1 \
  CXX="$CXX" AR="$AR" \
  CXXFLAGS="-Wall -fPIC -O2 -isysroot $SDKROOT -I$SOURCE/include -I$SOURCE/lib/updfparser/include -I/opt/homebrew/include -I/opt/homebrew/opt/pugixml/include -I/opt/homebrew/opt/libzip/include" \
  LDFLAGS="-L/opt/homebrew/lib -L/opt/homebrew/opt/openssl@3/lib -L/opt/homebrew/opt/curl/lib -lcrypto -lzip -lz -lcurl -lpugixml"
mkdir -p "$DEST"
cp "$SOURCE/utils/acsmdownloader" "$SOURCE/utils/adept_activate" "$SOURCE/utils/adept_remove" "$DEST/"

echo "Engine copied to $DEST"
