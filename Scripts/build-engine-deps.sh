#!/bin/zsh
set -euo pipefail

# Builds the engine's C dependencies as @rpath libraries with an older macOS
# deployment target, so released apps keep running on macOS older than the
# build host. Homebrew bottles are unusable here: their minos matches the
# machine Homebrew runs on.

ROOT="${0:A:h:h}"
DEPS="${LENTERA_DEPS:-$ROOT/.engine-deps}"
PREFIX="$DEPS/prefix"
SRC="$DEPS/src"
TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"
JOBS="$(sysctl -n hw.ncpu)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
TOOLCHAIN="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
if [[ ! -x "$TOOLCHAIN/clang++" ]]; then
  TOOLCHAIN="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin"
fi
CXX="$TOOLCHAIN/clang++"
CC="$TOOLCHAIN/clang"

OPENSSL_VERSION=3.6.4
OPENSSL_SHA256=9bffaa1ad1e07b354c21bd3324ec02fa15579f45a7d0494b3e74bc449b7333ef
CURL_VERSION=8.22.0
CURL_SHA256=f7ef3ae8a22e521f289803fe93543eb64c329b58aa73a9e224dfd915a2a5f4f7
LIBZIP_VERSION=1.11.4
LIBZIP_SHA256=82e9f2f2421f9d7c2466bbc3173cd09595a88ea37db0d559a9d0a2dc60dc722e
PUGIXML_VERSION=1.16
PUGIXML_SHA256=4cee1ca4aad395170f4c7a07824f3bdd41f28316c6e1e1090a1425b278ec0b4b

SCRIPT_HASH="$(shasum -a 256 "$0" | awk '{print $1}')"
if [[ -f "$PREFIX/.complete" && "$(<"$PREFIX/.complete")" == "$SCRIPT_HASH" ]]; then
  echo "Engine dependencies already built at $PREFIX"
  exit 0
fi

mkdir -p "$PREFIX" "$SRC"

fetch() {
  local url="$1" sha="$2" file="$SRC/$3"
  [[ -f "$file" ]] || curl -fsSL -o "$file" "$url"
  echo "$sha  $file" | shasum -a 256 -c - >/dev/null
}

echo "Building engine dependencies for macOS $TARGET in $PREFIX"

fetch "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" \
  "$OPENSSL_SHA256" "openssl-$OPENSSL_VERSION.tar.gz"
rm -rf "$SRC/openssl-$OPENSSL_VERSION"
tar -xzf "$SRC/openssl-$OPENSSL_VERSION.tar.gz" -C "$SRC"
(
  cd "$SRC/openssl-$OPENSSL_VERSION"
  ./Configure darwin64-arm64-cc shared no-tests \
    --prefix="$PREFIX" --openssldir="$PREFIX/ssl" CC="$CC" \
    -isysroot "$SDKROOT" "-mmacosx-version-min=$TARGET"
  make -j"$JOBS" build_libs
  make -j"$JOBS" build_modules
  make install_sw
)

fetch "https://curl.se/download/curl-$CURL_VERSION.tar.xz" \
  "$CURL_SHA256" "curl-$CURL_VERSION.tar.xz"
rm -rf "$SRC/curl-$CURL_VERSION"
tar -xJf "$SRC/curl-$CURL_VERSION.tar.xz" -C "$SRC"
(
  cd "$SRC/curl-$CURL_VERSION"
  PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" ./configure --prefix="$PREFIX" \
    --enable-shared --disable-static \
    --with-openssl="$PREFIX" \
    --without-libpsl --without-libssh2 --without-libidn2 --without-nghttp2 \
    --without-brotli --without-zstd \
    --disable-http2 --disable-ldap --disable-ldaps --disable-rtsp --disable-dict \
    --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp \
    --disable-gopher --disable-mqtt --disable-manual \
    CC="$CC" \
    CPPFLAGS="-isysroot $SDKROOT -mmacosx-version-min=$TARGET" \
    CFLAGS="-O2 -isysroot $SDKROOT -mmacosx-version-min=$TARGET" \
    LDFLAGS="-isysroot $SDKROOT -mmacosx-version-min=$TARGET"
  make -j"$JOBS"
  make install
)

fetch "https://libzip.org/download/libzip-$LIBZIP_VERSION.tar.gz" \
  "$LIBZIP_SHA256" "libzip-$LIBZIP_VERSION.tar.gz"
rm -rf "$SRC/libzip-$LIBZIP_VERSION" "$SRC/libzip-build"
tar -xzf "$SRC/libzip-$LIBZIP_VERSION.tar.gz" -C "$SRC"
cmake -S "$SRC/libzip-$LIBZIP_VERSION" -B "$SRC/libzip-build" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET" \
  -DCMAKE_OSX_SYSROOT="$SDKROOT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF \
  -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF \
  -DENABLE_COMMONCRYPTO=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF \
  -DENABLE_OPENSSL=ON -DOPENSSL_ROOT_DIR="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX"
cmake --build "$SRC/libzip-build" -j "$JOBS"
cmake --install "$SRC/libzip-build"

fetch "https://github.com/zeux/pugixml/releases/download/v$PUGIXML_VERSION/pugixml-$PUGIXML_VERSION.tar.gz" \
  "$PUGIXML_SHA256" "pugixml-$PUGIXML_VERSION.tar.gz"
rm -rf "$SRC/pugixml-$PUGIXML_VERSION" "$SRC/pugixml-build"
tar -xzf "$SRC/pugixml-$PUGIXML_VERSION.tar.gz" -C "$SRC"
cmake -S "$SRC/pugixml-$PUGIXML_VERSION" -B "$SRC/pugixml-build" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET" \
  -DCMAKE_OSX_SYSROOT="$SDKROOT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DPUGIXML_BUILD_TESTS=OFF
cmake --build "$SRC/pugixml-build" -j "$JOBS"
cmake --install "$SRC/pugixml-build"

# Reference sibling libraries through @rpath so the app bundle can relocate them.
for lib in "$PREFIX"/lib/*.dylib(N); do
  [[ -L "$lib" ]] && continue
  install_name_tool -id "@rpath/${lib:t}" "$lib"
done
for lib in "$PREFIX"/lib/*.dylib(N); do
  [[ -L "$lib" ]] && continue
  for dependency in "$PREFIX"/lib/*.dylib(N); do
    [[ -L "$dependency" ]] && continue
    install_name_tool -change "$dependency" "@rpath/${dependency:t}" "$lib" 2>/dev/null || true
  done
done

# The provider modules load into the engine tools. Point them at the libcrypto
# next to them, so they reuse the copy that is already in the app bundle.
for module in "$PREFIX"/lib/ossl-modules/*.dylib(N); do
  for dependency in "$PREFIX"/lib/*.dylib(N); do
    [[ -L "$dependency" ]] && continue
    install_name_tool -change "$dependency" "@loader_path/../${dependency:t}" "$module" 2>/dev/null || true
  done
done

echo "$SCRIPT_HASH" > "$PREFIX/.complete"
echo "Engine dependencies ready at $PREFIX"
