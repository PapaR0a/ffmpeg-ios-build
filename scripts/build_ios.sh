#!/bin/bash
set -e

echo "🚀 Starting FFmpeg iOS build..."

brew update
brew install nasm yasm pkg-config freetype libass

if [ ! -d "FFmpeg" ]; then
  git clone https://github.com/FFmpeg/FFmpeg.git
fi

cd FFmpeg

########################################
# DEVICE BUILD (arm64)
########################################
echo "📱 Building for iOS device..."

if [ -f "ffbuild/config.mak" ]; then
  make distclean
fi

ARCH=arm64
PLATFORM=iphoneos
SDK=$(xcrun --sdk $PLATFORM --show-sdk-path)

./configure \
--prefix=$(pwd)/build/device \
--target-os=darwin \
--arch=arm64 \
--enable-cross-compile \
--cc="$(xcrun --sdk $PLATFORM -f clang)" \
--sysroot=$SDK \
--extra-cflags="-arch arm64 -isysroot $SDK -mios-version-min=11.0" \
--extra-ldflags="-arch arm64 -isysroot $SDK -mios-version-min=11.0" \
--disable-debug \
--disable-doc \
--enable-static \
--disable-shared \
--enable-pic \
--enable-avformat \
--enable-avcodec \
--enable-avfilter \
--enable-swresample \
--enable-swscale \
--enable-avutil \
--enable-protocol=file \
--enable-demuxer=mov,mp4,mpegts \
--enable-muxer=mp4 \
--enable-decoder=h264,aac \
--enable-encoder=aac \
--enable-parser=h264,aac \
--enable-filter=scale \
--enable-filter=aresample \
--enable-filter=format \
--enable-filter=fps \
--enable-filter=overlay \
--enable-filter=transpose

make -j8
make install

########################################
# VERIFY OUTPUT
########################################
echo "🔍 Verifying build output..."

ls build/device/lib || true

echo "🔍 Checking fftools objects..."

find fftools -name "*.o" || true

########################################
# MERGE LIBRARIES
########################################
echo "🔗 Merging libraries..."

mkdir -p build/unified

# Device
libtool -static -o build/unified/libffmpeg_device.a \
build/device/lib/libavcodec.a \
build/device/lib/libavformat.a \
build/device/lib/libavfilter.a \
build/device/lib/libavutil.a \
build/device/lib/libswresample.a \
build/device/lib/libswscale.a \
fftools/ffmpeg.o \
fftools/cmdutils.o

########################################
# CREATE XCFRAMEWORK (FINAL WORKING)
########################################
echo "📦 Creating xcframework..."

cd ..

xcodebuild -create-xcframework \
-library FFmpeg/build/unified/libffmpeg_device.a \
-headers FFmpeg \
-output ffmpeg.xcframework

echo "✅ Build complete!"

echo "✅ Build complete!"
