#!/usr/bin/env bash
# Export the vector icon, then regenerate distribution sizes. Run from any directory.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_MASTER="$TASK_ROOT/branding/pickosaurus.png"
TASK_MENU_MASTER="$TASK_ROOT/branding/pickosaurus-menubar.png"
TASK_ICON_TOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
"$TASK_ICON_TOOL" "$TASK_ROOT/Pickosaurus/AppIcon.icon" --export-image \
  --output-file "$TASK_MASTER" --platform macOS --rendition Default \
  --width 1024 --height 1024 --scale 1
for TASK_SIZE in 16 32 64 128 256 512 1024; do
  sips -z "$TASK_SIZE" "$TASK_SIZE" "$TASK_MASTER" \
    --out "$TASK_ROOT/Pickosaurus/Assets.xcassets/AppIcon.appiconset/AppIcon-$TASK_SIZE.png" >/dev/null
done
for TASK_SIZE in 128 256 512; do
  cp "$TASK_ROOT/Pickosaurus/Assets.xcassets/AppIcon.appiconset/AppIcon-$TASK_SIZE.png" \
    "$TASK_ROOT/docs/assets/icon-$TASK_SIZE.png"
done
for TASK_SCALE in 1 2; do
  TASK_SIZE=$((20 * TASK_SCALE))
  sips -z "$TASK_SIZE" "$TASK_SIZE" "$TASK_MENU_MASTER" \
    --out "$TASK_ROOT/Pickosaurus/Assets.xcassets/MenuBarIcon.imageset/icon-${TASK_SCALE}x.png" >/dev/null
done
TASK_TEMP="$(mktemp -d)"
trap 'rm -rf "$TASK_TEMP"' EXIT
xcrun swift "$TASK_ROOT/scripts/make-dmg-background.swift" "$TASK_TEMP"
tiffutil -cathidpicheck "$TASK_TEMP/dmg-background-1x.png" "$TASK_TEMP/dmg-background-2x.png" \
  -out "$TASK_ROOT/scripts/dmg-background.tiff"
