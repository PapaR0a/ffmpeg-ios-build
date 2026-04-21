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

if [ -f "ffbuild/config.mak" ]; then
  make distclean
fi

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
--enable-swresample \
--enable-swscale

make -j8
make install

########################################
# SIMULATOR BUILD (arm64)
########################################
echo "🖥 Building for iOS simulator..."

if [ -f "ffbuild/config.mak" ]; then
  make distclean
fi

ARCH=arm64
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
--enable-swresample \
--enable-swscale

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
# CREATE FRAMEWORKS (REAL FIX)
########################################
echo "📦 Creating proper frameworks..."

mkdir -p build/frameworks/device/FFmpeg.framework
mkdir -p build/frameworks/sim/FFmpeg.framework

# Copy binaries
cp build/unified/libffmpeg_device.a build/frameworks/device/FFmpeg.framework/FFmpeg
cp build/unified/libffmpeg_sim.a build/frameworks/sim/FFmpeg.framework/FFmpeg

# Create Info.plist for device
cat > build/frameworks/device/FFmpeg.framework/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FFmpeg</string>
    <key>CFBundleIdentifier</key>
    <string>com.ffmpeg.device</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
EOF

# Create Info.plist for simulator
cat > build/frameworks/sim/FFmpeg.framework/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FFmpeg</string>
    <key>CFBundleIdentifier</key>
    <string>com.ffmpeg.sim</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
EOF

########################################
# CREATE XCFRAMEWORK (FINAL)
########################################
echo "📦 Creating xcframework..."

cd ..

xcodebuild -create-xcframework \
-framework FFmpeg/build/frameworks/device/FFmpeg.framework \
-framework FFmpeg/build/frameworks/sim/FFmpeg.framework \
-output ffmpeg.xcframework

echo "✅ Build complete!"