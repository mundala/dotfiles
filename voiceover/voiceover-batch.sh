#!/bin/bash
# ============================================
# voiceover-batch — render game dialogue from a CSV manifest
# ============================================
# Activates the dots.tts venv and runs batch.py.
#
# Install: symlink into PATH, e.g.
#   ln -sf ~/dotfiles/voiceover/voiceover-batch.sh ~/.local/bin/voiceover-batch
#
# Usage:
#   voiceover-batch lines.csv --out-dir game_audio --ogg
#   voiceover-batch lines.csv --dry-run

set -euo pipefail

DOTS_TTS_HOME="${DOTS_TTS_HOME:-$HOME/.local/share/dots.tts}"
VENV_DIR="$DOTS_TTS_HOME/.venv"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

[ -f "$VENV_DIR/bin/activate" ] || {
    echo "❌ venv missing — run voiceover/setup.sh first." >&2; exit 1; }

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
exec python "$SCRIPT_DIR/batch.py" "$@"
