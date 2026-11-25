#!/usr/bin/env bash
# Desert Fortress launcher for Linux (tested target: Linux Mint).
# Downloads the Godot engine once into ~/.local/share/desert-fortress and runs the game.
#   ./play.sh            run the game
#   ./play.sh --compat   use the OpenGL renderer (for older or Intel-only GPUs)
#   ./play.sh --editor   open the project in the Godot editor
set -euo pipefail

GODOT_VERSION="4.5.1"
DIR="$HOME/.local/share/desert-fortress"
BIN="$DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
PROJECT="$(cd "$(dirname "$0")" && pwd)"

if [ ! -x "$BIN" ]; then
	echo "Downloading Godot ${GODOT_VERSION} (about 50 MB, one time only)..."
	mkdir -p "$DIR"
	if command -v wget >/dev/null; then
		wget -q --show-progress -O "$DIR/godot.zip" "$URL"
	else
		curl -L --progress-bar -o "$DIR/godot.zip" "$URL"
	fi
	unzip -o -q "$DIR/godot.zip" -d "$DIR"
	rm "$DIR/godot.zip"
	chmod +x "$BIN"
fi

ARGS=()
case "${1:-}" in
	--compat) ARGS+=(--rendering-method gl_compatibility) ;;
	--editor) exec "$BIN" --editor --path "$PROJECT" ;;
esac

# First run imports the project; harmless afterwards.
if [ ! -d "$PROJECT/.godot" ]; then
	echo "Preparing project (first run)..."
	"$BIN" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true
fi

exec "$BIN" --path "$PROJECT" "${ARGS[@]}"
