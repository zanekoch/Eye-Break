#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="EyeBreak"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
TARGET_DIR="$HOME/Applications"

"$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_DIR/$APP_NAME.app"
cp -R "$SOURCE_APP" "$TARGET_DIR/"
touch "$TARGET_DIR/$APP_NAME.app"

echo "Installed $TARGET_DIR/$APP_NAME.app"
