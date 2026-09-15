#!/usr/bin/env bash
#
# Build, sign, notarize and package Pickosaurus for distribution (Homebrew Cask).
#
# Prerequisites:
#   1. A "Developer ID Application" certificate in your Keychain:
#        security find-identity -v -p codesigning | grep "Developer ID Application"
#   2. A stored notarization profile (one-time setup):
#        xcrun notarytool store-credentials pickosaurus-notary \
#          --apple-id "you@example.com" \
#          --team-id "YOURTEAMID" \
#          --password "app-specific-password"   # from appleid.apple.com
#
# Usage:
#   scripts/release.sh 1.0.0
#
set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh <version>  (e.g. 1.0.0)}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid release version" >&2; exit 2; }
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your Developer ID team}"
: "${PICKOSAURUS_UPDATE_REPOSITORY:?Set PICKOSAURUS_UPDATE_REPOSITORY to owner/repository}"
[[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "Invalid team ID" >&2; exit 2; }
[[ "$PICKOSAURUS_UPDATE_REPOSITORY" =~ ^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "Invalid repository" >&2; exit 2; }
export APPLE_TEAM_ID
NOTARY_PROFILE="${NOTARY_PROFILE:-pickosaurus-notary}"
SCHEME="Pickosaurus"
APP_NAME="Pickosaurus.app"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build/release"
EXPORT_DIR="$BUILD_DIR/export"
ARCHIVE="$BUILD_DIR/Pickosaurus.xcarchive"
ZIP_PATH="$ROOT/build/Pickosaurus-$VERSION.zip"
DMG_PATH="$ROOT/build/Pickosaurus-$VERSION.dmg"
VOLNAME="Pickosaurus"

# Submit a file to Apple's notary service and wait. Credentials come from env
# (CI) or a stored Keychain profile (local dev).
notarize() {
  local file="$1"
  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
    xcrun notarytool submit "$file" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
  else
    xcrun notarytool submit "$file" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
  fi
}

echo "==> Resolving Developer ID Application identity"
# Allow overriding via SIGN_IDENTITY (e.g. in CI); otherwise auto-detect.
DEV_ID="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')}"
if [[ -z "${DEV_ID:-}" ]]; then
  echo "ERROR: No 'Developer ID Application' certificate found in the Keychain." >&2
  echo "Create one in Xcode → Settings → Accounts → Manage Certificates → + Developer ID Application." >&2
  exit 1
fi
echo "    Using: $DEV_ID"

echo "==> Generating Xcode project"
(cd "$ROOT" && xcodegen generate)

echo "==> Archiving (Release)"
rm -rf "$BUILD_DIR"
xcodebuild -project "$ROOT/Pickosaurus.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEV_ID" \
  PRODUCT_BUNDLE_IDENTIFIER=com.pickosaurus.app \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  PICKOSAURUS_UPDATE_TEAM_IDENTIFIER="$APPLE_TEAM_ID" \
  PICKOSAURUS_UPDATE_REPOSITORY="$PICKOSAURUS_UPDATE_REPOSITORY" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  archive

echo "==> Exporting signed .app"
mkdir -p "$EXPORT_DIR"
cp -R "$ARCHIVE/Products/Applications/$APP_NAME" "$EXPORT_DIR/"

APP_PATH="$EXPORT_DIR/$APP_NAME"

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Verifying Pickosaurus release identity"
xcrun swiftc -parse-as-library \
  "$ROOT/Pickosaurus/Update/ReleaseConfiguration.swift" \
  "$ROOT/Pickosaurus/Update/ReleaseIdentity.swift" \
  "$ROOT/scripts/verify-release-identity.swift" \
  -o "$BUILD_DIR/verify-release-identity"
"$BUILD_DIR/verify-release-identity" "$APP_PATH"

echo "==> Creating ZIP for notarization"
mkdir -p "$ROOT/build"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting app to Apple notary service"
notarize "$ZIP_PATH"

echo "==> Stapling notarization ticket to the app"
xcrun stapler staple "$APP_PATH"

echo "==> Re-zipping stapled app (Homebrew cask artifact)"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Building DMG (drag-to-Applications installer)"
rm -f "$DMG_PATH"
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg not found. Add pkgs.create-dmg on nix-darwin, or install it with your package manager." >&2
  exit 1
fi
DMG_BACKGROUND="$ROOT/scripts/dmg-background.tiff"
create-dmg \
  --volname "$VOLNAME" \
  --background "$DMG_BACKGROUND" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 128 \
  --icon "$APP_NAME" 170 190 \
  --hide-extension "$APP_NAME" \
  --app-drop-link 470 190 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$EXPORT_DIR"
if [[ ! -f "$DMG_PATH" ]]; then
  echo "ERROR: DMG was not created." >&2
  exit 1
fi

echo "==> Signing DMG"
codesign --force --sign "$DEV_ID" --timestamp "$DMG_PATH"

echo "==> Submitting DMG to Apple notary service"
notarize "$DMG_PATH"

echo "==> Stapling notarization ticket to the DMG"
xcrun stapler staple "$DMG_PATH"

echo "==> Final Gatekeeper assessment"
spctl --assess --type execute --verbose=4 "$APP_PATH"

SHA=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
DMG_SHA=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

# Expose outputs for CI consumers.
echo "$SHA" > "$ROOT/build/Pickosaurus-$VERSION.sha256"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$VERSION"
    echo "sha256=$SHA"
    echo "zip_path=$ZIP_PATH"
    echo "dmg_path=$DMG_PATH"
    echo "dmg_sha256=$DMG_SHA"
  } >> "$GITHUB_OUTPUT"
fi

echo ""
echo "============================================================"
echo " Release artifacts ready"
echo "   ZIP:     $ZIP_PATH"
echo "   sha256:  $SHA"
echo "   DMG:     $DMG_PATH"
echo "   sha256:  $DMG_SHA"
echo "   Version: $VERSION"
echo "============================================================"
echo ""
echo "Next steps:"
echo "  1. Create a GitHub release tagged v$VERSION; upload the ZIP and DMG."
echo "  2. Render Casks/pickosaurus.rb.in with your repository, version and ZIP SHA-256."
