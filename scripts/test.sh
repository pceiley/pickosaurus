#!/bin/bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_BUILD="$TASK_ROOT/build/checks"
TASK_TEMP="$(mktemp -d)"
trap 'rm -rf "$TASK_TEMP"' EXIT

(cd "$TASK_ROOT" && xcodegen generate)

# Test bundles must never register as a usable web browser or compete with Debug.
python3 - "$TASK_ROOT/Pickosaurus/Info.plist" "$TASK_TEMP/Checks-Info.plist" <<'PYINFO'
import plistlib, sys
with open(sys.argv[1], "rb") as source:
    info = plistlib.load(source)
info.pop("CFBundleURLTypes", None)
with open(sys.argv[2], "wb") as output:
    plistlib.dump(info, output)
PYINFO

# The Debug dylib lets these checks exercise the built application directly,
# without launching its app delegate or linking a second app entry point.
xcodebuild -quiet \
    -project "$TASK_ROOT/Pickosaurus.xcodeproj" \
    -scheme Pickosaurus -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath "$TASK_BUILD" \
    INFOPLIST_FILE="$TASK_TEMP/Checks-Info.plist" \
    PRODUCT_NAME="Pickosaurus Checks" PRODUCT_BUNDLE_IDENTIFIER=com.pickosaurus.checks \
    CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=YES build

TASK_PRODUCTS="$TASK_BUILD/Build/Products/Debug"
TASK_BINARY_DIR="$TASK_PRODUCTS/Pickosaurus Checks.app/Contents/MacOS"
TASK_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TASK_PRODUCTS/Pickosaurus Checks.app/Contents/Info.plist")
if [[ "$TASK_BUNDLE_ID" != "com.pickosaurus.checks" ]]; then
    echo "FAIL: Test build must have its own bundle identity" >&2
    exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$TASK_PRODUCTS/Pickosaurus Checks.app/Contents/Info.plist" >/dev/null 2>&1; then
    echo "FAIL: Test app must not register web-link handlers" >&2
    exit 1
fi
for TASK_SOURCE in "$TASK_ROOT"/Tests/*Checks.swift; do
    TASK_NAME="$(basename "$TASK_SOURCE" .swift)"
    xcrun swiftc -parse-as-library \
        -I "$TASK_PRODUCTS" \
        "$TASK_SOURCE" \
        "$TASK_BINARY_DIR/Pickosaurus Checks.debug.dylib" \
        -Xlinker -rpath -Xlinker "$TASK_BINARY_DIR" \
        -o "$TASK_TEMP/$TASK_NAME"
    "$TASK_TEMP/$TASK_NAME"
done
