#!/bin/bash

set -euo pipefail

echo "============================================================"
echo " FFmpeg iOS ARM64 - Subtitle Build"
echo " FFmpeg + libass + FreeType + FriBidi + HarfBuzz"
echo "============================================================"

# ============================================================
# Paths
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FFMPEG_DIR="$ROOT_DIR/FFmpeg"
DEPS_DIR="$ROOT_DIR/dependencies"
BUILD_DIR="$ROOT_DIR/build-ios"
INSTALL_DIR="$BUILD_DIR/install"
OUTPUT_DIR="$ROOT_DIR/output"

mkdir -p "$DEPS_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# iOS configuration
# ============================================================

ARCH="arm64"
PLATFORM="iphoneos"
MIN_IOS_VERSION="13.0"

SDK="$(xcrun --sdk "$PLATFORM" --show-sdk-path)"

CC="$(xcrun --sdk "$PLATFORM" -f clang)"
CXX="$(xcrun --sdk "$PLATFORM" -f clang++)"
AR="$(xcrun --sdk "$PLATFORM" -f ar)"
RANLIB="$(xcrun --sdk "$PLATFORM" -f ranlib)"
STRIP="$(xcrun --sdk "$PLATFORM" -f strip)"
NM="$(xcrun --sdk "$PLATFORM" -f nm)"

export CC
export CXX
export AR
export RANLIB
export STRIP
export NM

export SDKROOT="$SDK"

export CFLAGS="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_IOS_VERSION -fPIC"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_IOS_VERSION"

# ============================================================
# pkg-config
# ============================================================

export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$INSTALL_DIR/lib/pkgconfig"

echo ""
echo "ROOT:"
echo "  $ROOT_DIR"

echo ""
echo "SDK:"
echo "  $SDK"

echo ""
echo "Compiler:"
echo "  $CC"

echo ""
echo "Architecture:"
echo "  $ARCH"

# ============================================================
# Homebrew tools
# ============================================================

echo ""
echo "============================================================"
echo " Installing build tools"
echo "============================================================"

brew update

brew install \
    nasm \
    yasm \
    pkg-config \
    autoconf \
    automake \
    libtool \
    cmake \
    meson \
    ninja \
    perl

# ============================================================
# gas-preprocessor
# ============================================================

GAS_DIR="$BUILD_DIR/gas-preprocessor"

if [ ! -f "$GAS_DIR/gas-preprocessor.pl" ]; then

    echo ""
    echo "Installing gas-preprocessor..."

    rm -rf "$GAS_DIR"

    git clone \
        https://github.com/FFmpeg/gas-preprocessor.git \
        "$GAS_DIR"
fi

chmod +x "$GAS_DIR/gas-preprocessor.pl"

export PATH="$GAS_DIR:$PATH"

# ============================================================
# Helper: clone and checkout a fixed tag
# ============================================================

checkout_repo()
{
    local NAME="$1"
    local URL="$2"
    local REF="$3"

    local DIR="$DEPS_DIR/$NAME"

    if [ ! -d "$DIR/.git" ]; then

        echo ""
        echo "Cloning $NAME..."

        git clone "$URL" "$DIR"

    fi

    cd "$DIR"

    git fetch --tags --force

    git checkout "$REF"
}

# ============================================================
# FreeType
# ============================================================

echo ""
echo "============================================================"
echo " Building FreeType"
echo "============================================================"

checkout_repo \
    "freetype" \
    "https://github.com/freetype/freetype.git" \
    "VER-2-13-3"

FREETYPE_DIR="$DEPS_DIR/freetype"
FREETYPE_BUILD="$FREETYPE_DIR/build-ios"

rm -rf "$FREETYPE_BUILD"

cmake -S "$FREETYPE_DIR" \
    -B "$FREETYPE_BUILD" \
    -G Ninja \
    \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS_VERSION" \
    \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    \
    -DCMAKE_C_FLAGS="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_IOS_VERSION -fPIC" \
    \
    -DCMAKE_CXX_FLAGS="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_IOS_VERSION -fPIC" \
    \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    \
    -DBUILD_SHARED_LIBS=OFF \
    -DFT_DISABLE_ZLIB=TRUE \
    -DFT_DISABLE_BZIP2=TRUE \
    -DFT_DISABLE_PNG=TRUE \
    -DFT_DISABLE_HARFBUZZ=TRUE \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$FREETYPE_BUILD" --parallel 1

cmake --install "$FREETYPE_BUILD"

if [ ! -f "$INSTALL_DIR/lib/libfreetype.a" ]; then
    echo "ERROR: FreeType build failed."
    exit 1
fi

echo "OK: FreeType built successfully."

# ============================================================
# FriBidi
# ============================================================

echo ""
echo "============================================================"
echo " Building FriBidi"
echo "============================================================"

checkout_repo \
    "fribidi" \
    "https://github.com/fribidi/fribidi.git" \
    "v1.0.16"

FRIBIDI_DIR="$DEPS_DIR/fribidi"

cd "$FRIBIDI_DIR"

if [ -f autogen.sh ]; then
    ./autogen.sh
fi

make distclean >/dev/null 2>&1 || true

HOST_SDK="$(xcrun --sdk macosx --show-sdk-path)"

env \
    SDKROOT="$HOST_SDK" \
    ./configure \
    --build=x86_64-apple-darwin \
    --host=arm-apple-darwin \
    --prefix="$INSTALL_DIR" \
    CC="$CC" \
    AR="$AR" \
    RANLIB="$RANLIB" \
    STRIP="$STRIP" \
    CFLAGS="$CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    --enable-static \
    --disable-shared \
    --disable-tools \
    --disable-docs \
    ac_cv_prog_cc_cross=yes \
    ac_cv_func_malloc_0_nonnull=yes

make -j1
make install

if [ ! -f "$INSTALL_DIR/lib/libfribidi.a" ]; then
    echo "ERROR: FriBidi build failed."
    exit 1
fi

echo "OK: FriBidi built successfully."

# ============================================================
# HarfBuzz
# ============================================================

echo ""
echo "============================================================"
echo " Building HarfBuzz"
echo "============================================================"

checkout_repo \
    "harfbuzz" \
    "https://github.com/harfbuzz/harfbuzz.git" \
    "10.4.0"

HARFBUZZ_BUILD="$DEPS_DIR/harfbuzz/build-ios"

rm -rf "$HARFBUZZ_BUILD"

cat > "$DEPS_DIR/harfbuzz-ios.ini" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
ranlib = '$RANLIB'
pkgconfig = '$(which pkg-config)'

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'

[properties]
needs_exe_wrapper = true

[built-in options]
c_args = [
    '-arch', '$ARCH',
    '-isysroot', '$SDK',
    '-miphoneos-version-min=$MIN_IOS_VERSION',
    '-I$INSTALL_DIR/include'
]

cpp_args = [
    '-arch', '$ARCH',
    '-isysroot', '$SDK',
    '-miphoneos-version-min=$MIN_IOS_VERSION',
    '-I$INSTALL_DIR/include'
]

c_link_args = [
    '-arch', '$ARCH',
    '-isysroot', '$SDK',
    '-miphoneos-version-min=$MIN_IOS_VERSION',
    '-L$INSTALL_DIR/lib',
    '-miphoneos-version-min=$MIN_IOS_VERSION'
]

cpp_link_args = [
    '-arch', '$ARCH',
    '-isysroot', '$SDK',
    '-miphoneos-version-min=$MIN_IOS_VERSION',
    '-L$INSTALL_DIR/lib',
    '-miphoneos-version-min=$MIN_IOS_VERSION'
]
EOF

meson setup "$HARFBUZZ_BUILD" \
    "$DEPS_DIR/harfbuzz" \
    --cross-file "$DEPS_DIR/harfbuzz-ios.ini" \
    --prefix="$INSTALL_DIR" \
    --libdir=lib \
    -Ddefault_library=static \
    -Dtests=disabled \
    -Ddocs=disabled \
    -Dutilities=disabled \
    -Dglib=disabled \
    -Dgobject=disabled \
    -Dicu=disabled \
    -Dgraphite2=disabled \
    -Dcairo=disabled \
    -Dcoretext=disabled \
    -Dbenchmark=disabled \
    -Dfreetype=enabled

meson compile -C "$HARFBUZZ_BUILD"
meson install -C "$HARFBUZZ_BUILD"

if [ ! -f "$INSTALL_DIR/lib/libharfbuzz.a" ]; then
    echo "ERROR: HarfBuzz build failed."
    exit 1
fi

# ============================================================
# libass
# ============================================================

echo ""
echo "============================================================"
echo " Building libass"
echo "============================================================"

checkout_repo \
    "libass" \
    "https://github.com/libass/libass.git" \
    "0.17.3"

cd "$DEPS_DIR/libass"

./autogen.sh

make distclean >/dev/null 2>&1 || true

./configure \
    --build="$(uname -m)-apple-darwin" \
    --host=arm-apple-darwin \
    --prefix="$INSTALL_DIR" \
    --enable-static \
    --disable-shared \
    --disable-fontconfig \
    --disable-directwrite \
    --disable-test \
    --disable-profile \
    --enable-harfbuzz

make -j1
make install

if [ ! -f "$INSTALL_DIR/lib/libass.a" ]; then
    echo "ERROR: libass build failed."
    exit 1
fi

# ============================================================
# Verify libass dependency chain
# ============================================================

echo ""
echo "============================================================"
echo " Verifying libass dependency chain"
echo "============================================================"

pkg-config --modversion libass
pkg-config --modversion freetype2
pkg-config --modversion fribidi
pkg-config --modversion harfbuzz

echo ""
echo "libass linker flags:"
pkg-config --static --libs libass

# ============================================================
# FFmpeg
# ============================================================

echo ""
echo "============================================================"
echo " Preparing FFmpeg"
echo "============================================================"

if [ ! -d "$FFMPEG_DIR/.git" ]; then

    echo ""
    echo "Cloning FFmpeg..."

    git clone \
        https://github.com/FFmpeg/FFmpeg.git \
        "$FFMPEG_DIR"

fi

cd "$FFMPEG_DIR"

git fetch --all --tags

# ============================================================
# PINNED FFmpeg VERSION
# ============================================================

FFMPEG_COMMIT="a48e31e501b950babcf7a47498ecf9e4e16cd7de"

echo ""
echo "FFmpeg commit:"
echo "  $FFMPEG_COMMIT"

git checkout "$FFMPEG_COMMIT"

echo ""
echo "Actual FFmpeg HEAD:"
git rev-parse HEAD

# ============================================================
# Clean previous FFmpeg build
# ============================================================

if [ -f "ffbuild/config.mak" ]; then
    make distclean
fi

rm -rf "$INSTALL_DIR/ffmpeg"

# ============================================================
# FFmpeg configure
# ============================================================

echo ""
echo "============================================================"
echo " Configuring FFmpeg"
echo "============================================================"

./configure \
    --prefix="$INSTALL_DIR/ffmpeg" \
    --target-os=darwin \
    --arch="$ARCH" \
    --enable-cross-compile \
    --cc="$CC" \
    --cxx="$CXX" \
    --ar="$AR" \
    --ranlib="$RANLIB" \
    --strip="$STRIP" \
    --nm="$NM" \
    --sysroot="$SDK" \
    \
    --extra-cflags="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_IOS_VERSION -I$INSTALL_DIR/include" \
    \
    --extra-cxxflags="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_IOS_VERSION -I$INSTALL_DIR/include" \
    \
    --extra-ldflags="-arch $ARCH -isysroot $SDK -miphoneos-version-min=$MIN_IOS_VERSION -L$INSTALL_DIR/lib" \
    \
    --pkg-config-flags="--static" \
    \
    --disable-debug \
    --disable-doc \
    --disable-programs \
    --enable-static \
    --disable-shared \
    --enable-pic \
    \
    --enable-avformat \
    --enable-avcodec \
    --enable-avfilter \
    --enable-swresample \
    --enable-swscale \
    --enable-avutil \
    \
    --enable-protocol=file \
    \
    --enable-demuxer=mov,mp4,mpegts \
    --enable-muxer=mp4 \
    \
    --enable-decoder=h264,aac \
    --enable-encoder=aac \
    --enable-parser=h264,aac \
    \
    --enable-filter=ass \
    --enable-filter=subtitles \
    --enable-filter=scale \
    --enable-filter=aresample \
    --enable-filter=format \
    --enable-filter=fps \
    --enable-filter=overlay \
    --enable-filter=transpose \
    \
    --enable-libass \
    --enable-libfreetype \

# ============================================================
# Verify FFmpeg configuration
# ============================================================

echo ""
echo "============================================================"
echo " Verifying FFmpeg configuration"
echo "============================================================"

if grep -q "CONFIG_LIBASS 1" config.h; then
    echo "OK: CONFIG_LIBASS enabled"
else
    echo "ERROR: CONFIG_LIBASS is NOT enabled."
    exit 1
fi

if grep -q "CONFIG_ASS_FILTER 1" config.h; then
    echo "OK: CONFIG_ASS_FILTER enabled"
else
    echo "ERROR: CONFIG_ASS_FILTER is NOT enabled."
    exit 1
fi

if grep -q "CONFIG_SUBTITLES_FILTER 1" config.h; then
    echo "OK: CONFIG_SUBTITLES_FILTER enabled"
else
    echo "ERROR: CONFIG_SUBTITLES_FILTER is NOT enabled."
    exit 1
fi

# ============================================================
# Build FFmpeg
# ============================================================

echo ""
echo "============================================================"
echo " Building FFmpeg"
echo "============================================================"

make -j1

make install

# ============================================================
# Verify FFmpeg libraries
# ============================================================

echo ""
echo "============================================================"
echo " Verifying FFmpeg libraries"
echo "============================================================"

for LIB in \
    libavcodec.a \
    libavformat.a \
    libavfilter.a \
    libavutil.a \
    libswresample.a \
    libswscale.a
do

    if [ ! -f "$INSTALL_DIR/ffmpeg/lib/$LIB" ]; then
        echo "ERROR: Missing $LIB"
        exit 1
    fi

    echo "OK: $LIB"

done

# ============================================================
# Create unified static library
# ============================================================

echo ""
echo "============================================================"
echo " Creating unified static library"
echo "============================================================"

UNIFIED_DIR="$BUILD_DIR/unified"

rm -rf "$UNIFIED_DIR"
mkdir -p "$UNIFIED_DIR"

UNIFIED_LIB="$UNIFIED_DIR/libffmpeg_device.a"

APPLE_LIBTOOL="$(xcrun --sdk iphoneos -f libtool)"

"$APPLE_LIBTOOL" \
    -static \
    -o "$UNIFIED_LIB" \
    \
    "$INSTALL_DIR/ffmpeg/lib/libavcodec.a" \
    "$INSTALL_DIR/ffmpeg/lib/libavformat.a" \
    "$INSTALL_DIR/ffmpeg/lib/libavfilter.a" \
    "$INSTALL_DIR/ffmpeg/lib/libavutil.a" \
    "$INSTALL_DIR/ffmpeg/lib/libswresample.a" \
    "$INSTALL_DIR/ffmpeg/lib/libswscale.a" \
    \
    "$INSTALL_DIR/lib/libass.a" \
    "$INSTALL_DIR/lib/libfreetype.a" \
    "$INSTALL_DIR/lib/libfribidi.a" \
    "$INSTALL_DIR/lib/libharfbuzz.a"

"$RANLIB" "$UNIFIED_LIB"

echo ""
echo "Checking subtitle symbols..."

if ! nm -g "$UNIFIED_LIB" | grep -q "ass_library_init"; then
    echo "ERROR: libass symbols were not found in unified library."
    exit 1
fi

if ! nm -g "$UNIFIED_LIB" | grep -q "FT_Init_FreeType"; then
    echo "ERROR: FreeType symbols were not found in unified library."
    exit 1
fi

echo "OK: libass symbols present"
echo "OK: FreeType symbols present"

echo ""
echo "Unified library:"
ls -lh "$UNIFIED_LIB"

# ============================================================
# Copy headers
# ============================================================

PACKAGE_DIR="$BUILD_DIR/package"

rm -rf "$PACKAGE_DIR"

mkdir -p "$PACKAGE_DIR/include"

cp -R "$INSTALL_DIR/ffmpeg/include/"* \
    "$PACKAGE_DIR/include/"

if [ -d "$INSTALL_DIR/include/ass" ]; then

    mkdir -p "$PACKAGE_DIR/include/ass"

    cp "$INSTALL_DIR/include/ass/"*.h \
        "$PACKAGE_DIR/include/ass/"

fi

# ============================================================
# Create XCFramework
# ============================================================

echo ""
echo "============================================================"
echo " Creating XCFramework"
echo "============================================================"

XCFRAMEWORK="$OUTPUT_DIR/ffmpeg.xcframework"

rm -rf "$XCFRAMEWORK"

xcodebuild -create-xcframework \
    -library "$UNIFIED_LIB" \
    -headers "$PACKAGE_DIR/include" \
    -output "$XCFRAMEWORK"

# ============================================================
# Final verification
# ============================================================

echo ""
echo "============================================================"
echo " FINAL VERIFICATION"
echo "============================================================"

test -d "$XCFRAMEWORK"

echo ""
echo "XCFramework:"
echo "  $XCFRAMEWORK"

echo ""
echo "Contents:"
find "$XCFRAMEWORK" -maxdepth 3 -type f | sort

echo ""
echo "Binary:"
file "$XCFRAMEWORK/ios-arm64/libffmpeg_device.a"

echo ""
echo "============================================================"
echo " BUILD SUCCESSFUL"
echo "============================================================"
