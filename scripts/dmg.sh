#!/usr/bin/env bash
# Packages build/Glance.app into a drag-to-install disk image (Glance.app + Applications shortcut).
#
#   ./scripts/bundle.sh && ./scripts/dmg.sh            # → build/Glance.dmg
#   ./scripts/dmg.sh build/Glance-v0.3.0.dmg           # custom output path (CI)
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Glance.app
OUT=${1:-build/Glance.dmg}
[[ -d "$APP" ]] || { echo "No $APP — run ./scripts/bundle.sh first." >&2; exit 1; }

STAGE=$(mktemp -d)
MNT=$(mktemp -d)
RW="$STAGE.rw.dmg"
trap 'hdiutil detach -quiet "$MNT" 2>/dev/null || true; rm -rf "$STAGE" "$MNT" "$RW"' EXIT

ditto "$APP" "$STAGE/Glance.app"
ln -s /Applications "$STAGE/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"

# Build read-write first so the volume can be flagged to use the custom icon, then compress.
hdiutil create -quiet -volname Glance -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW"
hdiutil attach -quiet -nobrowse -noautoopen -mountpoint "$MNT" "$RW"
if command -v SetFile >/dev/null; then SetFile -a C "$MNT"; fi
hdiutil detach -quiet "$MNT"
rm -f "$OUT"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT"
echo "Built $OUT"
