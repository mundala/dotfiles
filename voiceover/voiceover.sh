#!/bin/bash
# ============================================
# voiceover — clone your voice with dots.tts
# ============================================
# Thin wrapper around the dots.tts CLI for voice-over work:
#   • sensible defaults from a config file
#   • read a long script from a .txt file
#   • auto-chunk long text by sentence and stitch the audio back together
#
# Install: symlink this into PATH, e.g.
#   ln -sf ~/dotfiles/voiceover/voiceover.sh ~/.local/bin/voiceover
#
# Quick start:
#   voiceover --voice me.wav --voice-text "transcript of me.wav" \
#             --out vo.wav "Hello, this is my cloned voice."

set -euo pipefail

DOTS_TTS_HOME="${DOTS_TTS_HOME:-$HOME/.local/share/dots.tts}"
VENV_DIR="$DOTS_TTS_HOME/.venv"
MODEL_DIR="${DOTS_TTS_MODEL_DIR:-$DOTS_TTS_HOME/pretrained_models/dots.tts-soar}"
CONFIG_FILE="${VOICEOVER_CONFIG:-$HOME/.config/voiceover/config}"

# Defaults (overridable by config file, then CLI flags)
VOICE=""           # reference .wav of the voice to clone
VOICE_TEXT=""      # exact transcript of the reference clip
OUT="voiceover.wav"
STEPS=10           # flow-matching steps (higher = better/slower)
GUIDANCE=1.0
CHUNK=1            # 1 = split long text by sentence and stitch

# ---- Load config file (simple KEY=VALUE) ---------------------------------
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    VOICE="${VOICE_SAMPLE:-$VOICE}"
    VOICE_TEXT="${VOICE_SAMPLE_TEXT:-$VOICE_TEXT}"
fi

usage() {
    cat <<'EOF'
voiceover — clone your voice with dots.tts

USAGE:
  voiceover [options] "text to speak"
  voiceover [options] --from-file script.txt

OPTIONS:
  --voice FILE        Reference .wav of the voice to clone
  --voice-text TEXT   Exact transcript of the reference clip (improves cloning)
  --out FILE          Output .wav (default: voiceover.wav)
  --from-file FILE    Read the script to speak from a text file
  --steps N           Flow-matching steps (default: 10; try 16–25 for quality)
  --guidance F        Guidance scale (default: 1.0)
  --no-chunk          Disable sentence chunking (send text as one block)
  --model DIR         Model dir (default: $DOTS_TTS_MODEL_DIR)
  -h, --help          Show this help

CONFIG (~/.config/voiceover/config), so you can omit --voice each time:
  VOICE_SAMPLE="/home/you/voices/me.wav"
  VOICE_SAMPLE_TEXT="The exact words spoken in me.wav."
EOF
}

# ---- Parse args -----------------------------------------------------------
TEXT=""
FROM_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --voice)      VOICE="$2"; shift 2;;
        --voice-text) VOICE_TEXT="$2"; shift 2;;
        --out)        OUT="$2"; shift 2;;
        --from-file)  FROM_FILE="$2"; shift 2;;
        --steps)      STEPS="$2"; shift 2;;
        --guidance)   GUIDANCE="$2"; shift 2;;
        --no-chunk)   CHUNK=0; shift;;
        --model)      MODEL_DIR="$2"; shift 2;;
        -h|--help)    usage; exit 0;;
        -*)           echo "Unknown option: $1" >&2; usage; exit 1;;
        *)            TEXT="${TEXT:+$TEXT }$1"; shift;;
    esac
done

# ---- Resolve script text --------------------------------------------------
if [ -n "$FROM_FILE" ]; then
    [ -f "$FROM_FILE" ] || { echo "❌ Script file not found: $FROM_FILE" >&2; exit 1; }
    TEXT="$(cat "$FROM_FILE")"
fi

# ---- Validate -------------------------------------------------------------
[ -n "$TEXT" ]   || { echo "❌ No text to speak. See --help." >&2; exit 1; }
[ -n "$VOICE" ]  || { echo "❌ No --voice given (and none in config)." >&2; exit 1; }
[ -f "$VOICE" ]  || { echo "❌ Voice sample not found: $VOICE" >&2; exit 1; }
[ -d "$MODEL_DIR" ] || { echo "❌ Model not found: $MODEL_DIR (run setup.sh)" >&2; exit 1; }
[ -f "$VENV_DIR/bin/activate" ] || { echo "❌ venv missing: run voiceover/setup.sh" >&2; exit 1; }

if [ -z "$VOICE_TEXT" ]; then
    echo "⚠️  No --voice-text given. Cloning works best with the reference transcript."
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# One synthesis call -> single wav
synth() {  # $1=text  $2=outfile
    local args=(
        --model-name-or-path "$MODEL_DIR"
        --text "$1"
        --prompt-audio "$VOICE"
        --output "$2"
        --num-steps "$STEPS"
        --guidance-scale "$GUIDANCE"
    )
    [ -n "$VOICE_TEXT" ] && args+=(--prompt-text "$VOICE_TEXT")
    dots.tts "${args[@]}"
}

# ---- Short text: one shot -------------------------------------------------
WORDS="$(printf '%s' "$TEXT" | wc -w)"
if [ "$CHUNK" -eq 0 ] || [ "$WORDS" -le 60 ]; then
    echo "🎙️  Synthesizing (${WORDS} words) → $OUT"
    synth "$TEXT" "$OUT"
    deactivate
    echo "✅ Wrote $OUT"
    exit 0
fi

# ---- Long text: split by sentence, synth each, stitch --------------------
echo "🎙️  Long script (${WORDS} words) — chunking by sentence..."
TMPDIR_VO="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_VO"' EXIT

# Split into sentences (handles . ! ? and blank lines) via python.
VO_TEXT="$TEXT" python - "$TMPDIR_VO" <<'PY'
import sys, re, os
outdir = sys.argv[1]
text = os.environ["VO_TEXT"]
# Split on sentence enders followed by space/newline, keep it simple & robust.
parts = re.split(r'(?<=[.!?])\s+|\n{2,}', text)
parts = [p.strip() for p in parts if p.strip()]
for i, p in enumerate(parts):
    with open(os.path.join(outdir, f"sent_{i:04d}.txt"), "w") as f:
        f.write(p)
print(f"{len(parts)} chunks")
PY

i=0
CHUNK_WAVS=()
for sf_txt in "$TMPDIR_VO"/sent_*.txt; do
    [ -e "$sf_txt" ] || break
    chunk_text="$(cat "$sf_txt")"
    out_wav="$TMPDIR_VO/chunk_$(printf '%04d' "$i").wav"
    echo "   • chunk $((i+1)): ${chunk_text:0:50}..."
    synth "$chunk_text" "$out_wav"
    CHUNK_WAVS+=("$out_wav")
    i=$((i+1))
done

echo "🔗 Stitching $i chunks → $OUT"
if command -v sox >/dev/null 2>&1; then
    sox "${CHUNK_WAVS[@]}" "$OUT"
elif command -v ffmpeg >/dev/null 2>&1; then
    list_file="$TMPDIR_VO/concat.txt"
    for w in "${CHUNK_WAVS[@]}"; do echo "file '$w'" >> "$list_file"; done
    ffmpeg -y -f concat -safe 0 -i "$list_file" -c copy "$OUT" >/dev/null 2>&1
else
    echo "❌ Need sox or ffmpeg to stitch chunks. Install one and retry." >&2
    exit 1
fi

deactivate
echo "✅ Wrote $OUT ($i chunks)"
