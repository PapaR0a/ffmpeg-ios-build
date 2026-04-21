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
# CREATE XCFRAMEWORK
########################################
echo "📦 Creating xcframework..."

cd ..

xcodebuild -create-xcframework \
-library FFmpeg/build/device/lib/libavcodec.a \
-library FFmpeg/build/sim/lib/libavcodec.a \
-library FFmpeg/build/device/lib/libavformat.a \
-library FFmpeg/build/sim/lib/libavformat.a \
-library FFmpeg/build/device/lib/libavutil.a \
-library FFmpeg/build/sim/lib/libavutil.a \
-library FFmpeg/build/device/lib/libswresample.a \
-library FFmpeg/build/sim/lib/libswresample.a \
-output ffmpeg.xcframework

echo "✅ Build complete!"
