#!/usr/bin/env bash
# Builds a standalone Linux version of Desert Fortress: one file you can run
# without Godot or this source folder, written to build/desert-fortress.x86_64.
#   ./export.sh
# The first time it downloads Godot's export templates (about 1.3 GB, one time
# only) and keeps just the two Linux templates (about 150 MB).
set -euo pipefail

GODOT_VERSION="4.5.1"
DIR="$HOME/.local/share/desert-fortress"
BIN="$DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
TPL="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
TPL_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
PROJECT="$(cd "$(dirname "$0")" && pwd)"

if [ ! -x "$BIN" ]; then
	echo "Godot is not downloaded yet: run ./play.sh once first."
	exit 1
fi

if [ ! -f "$TPL/linux_release.x86_64" ]; then
	echo "Downloading Godot export templates (about 1.3 GB, one time only)..."
	TMP="$(mktemp -d)"
	if command -v wget >/dev/null; then
		wget -q --show-progress -O "$TMP/t.tpz" "$TPL_URL"
	else
		curl -L --progress-bar -o "$TMP/t.tpz" "$TPL_URL"
	fi
	mkdir -p "$TPL"
	unzip -o -q -j "$TMP/t.tpz" 'templates/linux_release.x86_64' 'templates/linux_debug.x86_64' 'templates/version.txt' -d "$TPL"
	rm -rf "$TMP"
fi

mkdir -p "$PROJECT/build"
"$BIN" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true
"$BIN" --headless --path "$PROJECT" --export-release "Linux" "$PROJECT/build/desert-fortress.x86_64"
echo
echo "Done: $PROJECT/build/desert-fortress.x86_64"
echo "Copy that one file anywhere and run it. Add --rendering-method gl_compatibility for older GPUs."
