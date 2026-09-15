#!/usr/bin/env bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_BUILD="${DEBUG_BUILD_DIR:-$TASK_ROOT/build/debug-preview}"
TASK_PRODUCTS="$TASK_BUILD/Products"
TASK_APP="$TASK_PRODUCTS/Pickosaurus Debug.app"
TASK_ZIP="$TASK_BUILD/Pickosaurus-Debug.zip"

cd "$TASK_ROOT"
xcodegen generate
xcodebuild -quiet -project Pickosaurus.xcodeproj -scheme Pickosaurus \
    -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$TASK_BUILD/DerivedData" \
    CONFIGURATION_BUILD_DIR="$TASK_PRODUCTS" \
    PRODUCT_NAME="Pickosaurus Debug" PRODUCT_MODULE_NAME=Pickosaurus \
    PRODUCT_BUNDLE_IDENTIFIER=com.pickosaurus.debug \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG PICKOSAURUS_DEBUG' \
    CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO ONLY_ACTIVE_ARCH=YES build

# Prefer a stable local development identity for local macOS testing.
TASK_IDENTITY="${DEBUG_SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | awk '/"Apple Development:/{print $2; exit}')}"
codesign --force --sign "${TASK_IDENTITY:--}" --entitlements "$TASK_ROOT/Pickosaurus/Pickosaurus.entitlements" "$TASK_APP"
codesign --verify --strict "$TASK_APP"
ditto -c -k --sequesterRsrc --keepParent "$TASK_APP" "$TASK_ZIP"
printf 'App: %s\nZIP: %s\n' "$TASK_APP" "$TASK_ZIP"
