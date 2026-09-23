#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE="${1:-$ROOT/Vendor/libgourou}"
DEST="$ROOT/Sources/Lentera/Resources/tools"
DEPS="${LENTERA_DEPS:-$ROOT/.engine-deps/prefix}"
TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

if [[ ! -d "$SOURCE" ]]; then
  echo "libgourou source not found at $SOURCE"
  echo "Pass its path: Scripts/build-engine.sh /path/to/libgourou"
  exit 1
fi

"$ROOT/Scripts/build-engine-deps.sh"

export MACOSX_DEPLOYMENT_TARGET="$TARGET"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
TOOLCHAIN="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
if [[ ! -x "$TOOLCHAIN/clang++" ]]; then
  TOOLCHAIN="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin"
fi
CXX="$TOOLCHAIN/clang++"
AR="$TOOLCHAIN/ar"

STATIC_LIBS=""
COMMON_FLAGS="-Wall -fPIC -O2 -isysroot $SDKROOT -mmacosx-version-min=$TARGET"

make -C "$SOURCE/lib/updfparser" clean all BUILD_STATIC=1 BUILD_SHARED=0 CXX="$CXX" AR="$AR" \
  CXXFLAGS="$COMMON_FLAGS -I./include"
make -C "$SOURCE" clean all BUILD_STATIC=1 BUILD_SHARED=0 STATIC_UTILS=1 \
  CXX="$CXX" AR="$AR" \
  CXXFLAGS="$COMMON_FLAGS -I$SOURCE/include -I$SOURCE/lib/updfparser/include -I$DEPS/include" \
  LDFLAGS="-L$DEPS/lib -mmacosx-version-min=$TARGET -Wl,-rpath,@loader_path/lib -lcurl -lzip -lpugixml -lssl -lcrypto -lz"
mkdir -p "$DEST"
cp "$SOURCE/utils/acsmdownloader" "$SOURCE/utils/adept_activate" "$SOURCE/utils/adept_remove" \
  "$SOURCE/utils/adept_loan_mgt" "$DEST/"

echo "Engine copied to $DEST"
