#!/bin/bash
# ============================================
# dots.tts Voice-Over Setup
# CachyOS / Arch  •  Legion Pro 7 (RTX 5070 Ti, Blackwell sm_120)
# ============================================
# Installs rednote-hilab/dots.tts into an isolated Python 3.10 venv,
# fixes the Blackwell/torch CUDA mismatch, and downloads the SOAR model.
#
# Usage:  ./setup.sh
# Re-run safe (idempotent-ish): skips clone/download if already present.

set -euo pipefail

# ---- Config (override via env) -------------------------------------------
DOTS_TTS_HOME="${DOTS_TTS_HOME:-$HOME/.local/share/dots.tts}"
DOTS_TTS_REPO="${DOTS_TTS_REPO:-https://github.com/rednote-hilab/dots.tts.git}"
DOTS_TTS_MODEL="${DOTS_TTS_MODEL:-rednote-hilab/dots.tts-soar}"
VENV_DIR="$DOTS_TTS_HOME/.venv"
MODEL_DIR="$DOTS_TTS_HOME/pretrained_models/dots.tts-soar"
PY_VERSION="3.10"
# Blackwell (RTX 50-series) needs a torch built against CUDA 12.8+
TORCH_CUDA_INDEX="https://download.pytorch.org/whl/cu128"

echo "🎙️  Installing dots.tts voice-over toolkit..."
echo "    Home:  $DOTS_TTS_HOME"

# ---- 1. System packages ---------------------------------------------------
echo "📦 Installing system packages..."
sudo pacman -S --noconfirm --needed git ffmpeg sox python || true

# uv handles the Python 3.10 toolchain cleanly without conda bloat.
if ! command -v uv >/dev/null 2>&1; then
    echo "📦 Installing uv..."
    sudo pacman -S --noconfirm --needed uv 2>/dev/null || \
        curl -LsSf https://astral.sh/uv/install.sh | sh
    # Pick up uv if the installer dropped it in ~/.local/bin
    export PATH="$HOME/.local/bin:$PATH"
fi

# ---- 2. Clone the repo ----------------------------------------------------
mkdir -p "$DOTS_TTS_HOME"
if [ ! -d "$DOTS_TTS_HOME/repo/.git" ]; then
    echo "⬇️  Cloning dots.tts..."
    git clone --depth 1 "$DOTS_TTS_REPO" "$DOTS_TTS_HOME/repo"
else
    echo "✔️  Repo already cloned — pulling latest..."
    git -C "$DOTS_TTS_HOME/repo" pull --ff-only || true
fi
cd "$DOTS_TTS_HOME/repo"

# ---- 3. Python 3.10 venv + install ---------------------------------------
echo "🐍 Creating Python $PY_VERSION venv..."
uv venv --python "$PY_VERSION" "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "📦 Installing dots.tts (this pulls torch + deps, ~a few minutes)..."
uv pip install --upgrade pip
if [ -f constraints/recommended.txt ]; then
    uv pip install -e . -c constraints/recommended.txt
else
    uv pip install -e .
fi
uv pip install "huggingface_hub[cli]" soundfile

# ---- 4. Blackwell / sm_120 torch fix -------------------------------------
# The pinned torch often lacks RTX 50-series (sm_120) kernels. Detect and fix.
echo "🔍 Checking GPU/torch compatibility (Blackwell sm_120)..."
NEEDS_TORCH_FIX="$(python - <<'PY'
try:
    import torch
    archs = torch.cuda.get_arch_list() if torch.cuda.is_available() or True else []
    print("no" if "sm_120" in archs else "yes")
except Exception:
    print("yes")
PY
)"
if [ "$NEEDS_TORCH_FIX" = "yes" ]; then
    echo "⚠️  Installed torch lacks sm_120 kernels — reinstalling CUDA 12.8 build..."
    uv pip install --reinstall torch torchaudio --index-url "$TORCH_CUDA_INDEX" || \
        echo "⚠️  cu128 reinstall failed — see voiceover/README.md troubleshooting."
else
    echo "✔️  torch already supports your RTX 5070 Ti (sm_120)."
fi

# ---- 5. Download the SOAR model ------------------------------------------
if [ ! -d "$MODEL_DIR" ] || [ -z "$(ls -A "$MODEL_DIR" 2>/dev/null || true)" ]; then
    echo "⬇️  Downloading model $DOTS_TTS_MODEL (several GB)..."
    hf download "$DOTS_TTS_MODEL" --local-dir "$MODEL_DIR" || \
        huggingface-cli download "$DOTS_TTS_MODEL" --local-dir "$MODEL_DIR"
else
    echo "✔️  Model already downloaded at $MODEL_DIR"
fi

deactivate

echo ""
echo "✅ Done! dots.tts is installed."
echo ""
echo "Next steps:"
echo "  1. Add the helper to PATH (or symlink it):"
echo "       ln -sf \"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/voiceover.sh\" ~/.local/bin/voiceover"
echo "  2. Record a clean 5–15s sample of your voice as a .wav (mono, no noise)."
echo "  3. Generate a voice-over:"
echo "       voiceover --voice my_voice.wav --voice-text \"exact transcript of the sample\" \\"
echo "                 --out vo.wav \"The text you want spoken in your voice.\""
echo ""
echo "🎙️  See voiceover/README.md for tips on long scripts & quality."
