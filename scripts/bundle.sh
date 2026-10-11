#!/usr/bin/env bash
# Builds a release binary and wraps it into build/Glance.app (no Xcode required).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Glance.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Glance" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"   # ad-hoc sign so macOS will launch it
echo "Built $APP — run: open $APP"
