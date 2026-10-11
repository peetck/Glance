#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) release binary and wraps it into
# build/Glance.app with the app icon. No Xcode required.
#
#   ./scripts/bundle.sh                  # version from Resources/Info.plist
#   VERSION=0.2.0 ./scripts/bundle.sh    # override (CI passes the git tag)
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Glance.app
PLIST="$APP/Contents/Info.plist"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Build each arch separately and copy it out right away: some SwiftPM versions use the same
# output path for every arch. (Building both in one `swift build` needs full Xcode.)
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch"
    cp "$(swift build -c release --arch "$arch" --show-bin-path)/Glance" "build/Glance-$arch"
done
lipo -create -output "$APP/Contents/MacOS/Glance" build/Glance-arm64 build/Glance-x86_64
rm build/Glance-arm64 build/Glance-x86_64

cp Resources/Info.plist "$PLIST"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
fi
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"

# App icon: render every size macOS wants from the 1024px PNG, then pack into .icns.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size assets/glance-icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) assets/glance-icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

codesign --force --sign - "$APP"   # ad-hoc sign so macOS will launch it
echo "Built $APP ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")) — run: open $APP"
