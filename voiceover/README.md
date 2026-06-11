# 🎙️ voiceover — clone your voice with dots.tts

Tools to install and use [rednote-hilab/dots.tts](https://github.com/rednote-hilab/dots.tts)
for zero-shot voice cloning / voice-over work, tuned for an
**RTX 5070 Ti (Blackwell, sm_120)** on CachyOS/Arch.

`dots.tts` is a 2B-parameter, fully-continuous autoregressive TTS system
(Qwen2.5-1.5B backbone + flow-matching acoustic head over a 48 kHz AudioVAE).
It does zero-shot cloning from a short reference clip — no training required.
Apache-2.0 licensed.

## Install

```bash
cd ~/dotfiles/voiceover
./setup.sh
# then put the helper on PATH:
ln -sf ~/dotfiles/voiceover/voiceover.sh ~/.local/bin/voiceover
```

This creates an isolated Python 3.10 venv at `~/.local/share/dots.tts/.venv`,
installs dots.tts, downloads the `dots.tts-soar` model, and fixes the
Blackwell/torch CUDA mismatch (see below).

## Record your reference clip

- **5–15 seconds** of clean speech, mono `.wav`, 1 speaker, no music/noise.
- Note the **exact transcript** — passing it as `--voice-text` noticeably
  improves clone fidelity.

```bash
# Example: record with ffmpeg (Ctrl-C to stop)
ffmpeg -f pulse -i default -ac 1 -ar 48000 me.wav
```

## Use

```bash
# One line
voiceover --voice me.wav --voice-text "The exact words spoken in me.wav." \
          --out hello.wav "Hello, this is my cloned voice."

# A whole script from a file (auto-chunked by sentence + stitched)
voiceover --from-file script.txt --out narration.wav

# Higher quality (slower)
voiceover --from-file script.txt --steps 20 --out narration.wav
```

### Set defaults so you can skip `--voice` every time

`~/.config/voiceover/config`:

```bash
VOICE_SAMPLE="/home/you/voices/me.wav"
VOICE_SAMPLE_TEXT="The exact words spoken in me.wav."
```

Then just: `voiceover --from-file script.txt --out vo.wav`

## Quality tips

- **`--voice-text`** matters most — give the real transcript of your sample.
- **Reference quality = output quality.** A clean, expressive 10s clip in the
  tone you want (calm narration vs. energetic) sets the style.
- **`--steps`**: 10 is fast; 16–25 sounds better for finished voice-overs.
- Long scripts are split by sentence and stitched, which also keeps AR drift
  in check. Use `--no-chunk` to force a single block.

## Troubleshooting

**`no kernel image is available for execution` / sm_120 errors**
Your torch build predates Blackwell. The installer auto-fixes this; to redo
it manually:
```bash
source ~/.local/share/dots.tts/.venv/bin/activate
uv pip install --reinstall torch torchaudio --index-url https://download.pytorch.org/whl/cu128
```

**CLI flag names differ**
dots.tts is young and flags may change. If a flag is rejected, check the real
ones and adjust `voiceover.sh`'s `synth()`:
```bash
source ~/.local/share/dots.tts/.venv/bin/activate
dots.tts --help
```
The wrapper currently assumes: `--model-name-or-path --text --prompt-audio
--prompt-text --output --num-steps --guidance-scale`.

**Out of VRAM** (unlikely at 12 GB for a 2B model)
Lower `--steps`, or set `precision="bfloat16"` (default) in the Python API.

## ⚠️ Use responsibly
Only clone voices you own or have explicit consent to use. Cloning your own
voice for your own voice-overs is exactly what this is for.
