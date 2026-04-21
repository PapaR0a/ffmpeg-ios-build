#!/bin/bash
set -e

echo "🚀 Starting FFmpeg iOS build..."

brew update
brew install nasm yasm pkg-config

if [ ! -d "FFmpeg" ]; then
  git clone https://github.com/FFmpeg/FFmpeg.git
fi

cd FFmpeg

########################################
# DEVICE BUILD (arm64)
########################################
echo "📱 Building for iOS device..."

make distclean || true

ARCH=arm64
PLATFORM=iphoneos
SDK=$(xcrun --sdk $PLATFORM --show-sdk-path)

./configure \
--prefix=$(pwd)/build/device \
--target-os=darwin \
--arch=$ARCH \
--enable-cross-compile \
--cc="$(xcrun --sdk $PLATFORM -f clang)" \
--sysroot=$SDK \
--extra-cflags="-arch $ARCH -mios-version-min=11.0" \
--extra-ldflags="-arch $ARCH -mios-version-min=11.0" \
--disable-debug \
--disable-doc \
--disable-programs \
--enable-static \
--disable-shared \
--disable-everything \
--enable-protocol=file \
--enable-demuxer=mov,mp4 \
--enable-muxer=mp4 \
--enable-decoder=aac,h264 \
--enable-encoder=aac \
--enable-avformat \
--enable-avcodec \
--enable-avutil \
--enable-swresample

make -j8
make install

########################################
# SIMULATOR BUILD (x86_64 - safer)
########################################
echo "🖥 Building for iOS simulator..."

make distclean || true

ARCH=x86_64
PLATFORM=iphonesimulator
SDK=$(xcrun --sdk $PLATFORM --show-sdk-path)

./configure \
--prefix=$(pwd)/build/sim \
--target-os=darwin \
--arch=$ARCH \
--enable-cross-compile \
--cc="$(xcrun --sdk $PLATFORM -f clang)" \
--sysroot=$SDK \
--extra-cflags="-arch $ARCH -mios-version-min=11.0" \
--extra-ldflags="-arch $ARCH -mios-version-min=11.0" \
--disable-debug \
--disable-doc \
--disable-programs \
--enable-static \
--disable-shared \
--disable-everything \
--enable-protocol=file \
--enable-demuxer=mov,mp4 \
--enable-muxer=mp4 \
--enable-decoder=aac,h264 \
--enable-encoder=aac \
--enable-avformat \
--enable-avcodec \
--enable-avutil \
--enable-swresample

make -j8
make install

########################################
# VERIFY OUTPUT
########################################
echo "🔍 Verifying build output..."

ls build/device/lib || true
ls build/sim/lib || true

########################################
# MERGE LIBRARIES
########################################
echo "🔗 Merging libraries..."

mkdir -p build/unified

# Device
libtool -static -o build/unified/libffmpeg_device.a \
build/device/lib/libavcodec.a \
build/device/lib/libavformat.a \
build/device/lib/libavutil.a \
build/device/lib/libswresample.a \
build/device/lib/libswscale.a

# Simulator
libtool -static -o build/unified/libffmpeg_sim.a \
build/sim/lib/libavcodec.a \
build/sim/lib/libavformat.a \
build/sim/lib/libavutil.a \
build/sim/lib/libswresample.a \
build/sim/lib/libswscale.a

########################################
# CREATE XCFRAMEWORK
########################################
echo "📦 Creating xcframework..."

cd ..

xcodebuild -create-xcframework \
-library FFmpeg/build/unified/libffmpeg_device.a \
-library FFmpeg/build/unified/libffmpeg_sim.a \
-output ffmpeg.xcframework

echo "✅ Build complete!"
