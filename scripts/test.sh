#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ipbar-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$PROJECT_ROOT"
xcodebuild -project IPBar.xcodeproj -scheme IPBar -configuration Debug \
    -derivedDataPath "$TEST_DIR" -destination 'platform=macOS' test
