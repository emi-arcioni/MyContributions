#!/bin/sh
# Builds build/MyContributions.app with the Command Line Tools (no Xcode needed).
set -eu
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/MyContributions"

APP=build/MyContributions.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/"
cp MenuBar/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"   # local-only signature, no Apple ID

echo "Built $APP"
