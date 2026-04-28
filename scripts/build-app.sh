#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/BatteryScheduler"
APP_DIR="$ROOT_DIR/dist/BatteryScheduler.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/BatteryScheduler"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

swift build -c release --package-path "$PACKAGE_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$PACKAGE_DIR/.build/release/BatteryScheduler" "$EXECUTABLE"
cp "$PACKAGE_DIR/Info.plist" "$INFO_PLIST"

set_plist_value() {
  local key="$1"
  local type="$2"
  local value="$3"

  /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :$key $value" "$INFO_PLIST"
}

set_plist_value CFBundleExecutable string BatteryScheduler
set_plist_value CFBundleIdentifier string com.inje.BatteryScheduler
set_plist_value CFBundleName string BatteryScheduler
set_plist_value CFBundleDisplayName string BatteryScheduler
set_plist_value CFBundlePackageType string APPL
set_plist_value CFBundleShortVersionString string 0.1.0
set_plist_value CFBundleVersion string 1

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
