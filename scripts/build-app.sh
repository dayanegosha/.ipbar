#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ipbar-build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
cd "$PROJECT_ROOT"

xcodebuild -project IPBar.xcodeproj -scheme IPBar -configuration Release \
    -derivedDataPath "$STAGING_DIR/DerivedData" -destination 'generic/platform=macOS' \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build

STAGED_APP="$STAGING_DIR/ipbar.app"
ditto --norsrc --noextattr "$STAGING_DIR/DerivedData/Build/Products/Release/ipbar.app" "$STAGED_APP"
codesign --force --options runtime --sign "${CODE_SIGN_IDENTITY:--}" "$STAGED_APP"
codesign --verify --strict --deep "$STAGED_APP"
architectures="$(lipo -archs "$STAGED_APP/Contents/MacOS/ipbar")"
[[ " $architectures " == *' arm64 '* && " $architectures " == *' x86_64 '* ]]
mkdir -p dist
rm -rf 'dist/ipbar.app'
ditto --norsrc --noextattr "$STAGED_APP" 'dist/ipbar.app'
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" dist/ipbar-macOS.zip
printf '\nBuilt %s\n' "$PROJECT_ROOT/dist/ipbar-macOS.zip"
