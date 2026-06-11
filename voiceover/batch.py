#!/usr/bin/env python3
"""
voiceover batch generator for game assets (dots.tts).

Reads a CSV manifest of dialogue lines and renders one audio file per line,
organized into per-character folders ready to drop into a Godot project.

CSV columns (header row required); only character/filename/text are mandatory:
    character,filename,text,emotion
    guard,greet_01,"Halt! Who goes there?",angry
    guard,idle_01,"Another quiet night...",neutral
    npc_merchant,welcome,"Welcome, traveler! Take a look.",

Per-character voices live in a voices dir (default ~/.config/voiceover/voices):
    voices/guard.wav            + voices/guard.txt            (transcript)
    voices/guard.angry.wav      + voices/guard.angry.txt      (optional emotion variant)
A line's emotion picks <character>.<emotion>.wav if present, else <character>.wav.

Run via the wrapper:  voiceover-batch manifest.csv --out-dir game_audio --ogg
"""
import argparse
import csv
import os
import shutil
import subprocess
import sys


def resolve_voice(voices_dir, character, emotion):
    """Return (wav_path, transcript) for a character/emotion, or (None, None)."""
    candidates = []
    if emotion:
        candidates.append(f"{character}.{emotion}")
    candidates.append(character)
    for stem in candidates:
        wav = os.path.join(voices_dir, f"{stem}.wav")
        if os.path.isfile(wav):
            txt = os.path.join(voices_dir, f"{stem}.txt")
            transcript = ""
            if os.path.isfile(txt):
                with open(txt, encoding="utf-8") as f:
                    transcript = f.read().strip()
            return wav, transcript
    return None, None


def main():
    ap = argparse.ArgumentParser(description="Batch game-audio generator (dots.tts)")
    ap.add_argument("manifest", help="CSV manifest of lines")
    ap.add_argument("--voices-dir",
                    default=os.path.expanduser("~/.config/voiceover/voices"),
                    help="Dir of <character>[.<emotion>].wav + .txt reference clips")
    ap.add_argument("--out-dir", default="game_audio",
                    help="Output root; files go to <out-dir>/<character>/<filename>.wav")
    ap.add_argument("--model",
                    default=os.path.expanduser(
                        "~/.local/share/dots.tts/pretrained_models/dots.tts-soar"),
                    help="dots.tts model dir")
    ap.add_argument("--steps", type=int, default=16,
                    help="Flow-matching steps (default 16; lines are short)")
    ap.add_argument("--guidance", type=float, default=1.0)
    ap.add_argument("--ogg", action="store_true",
                    help="Also export .ogg next to each .wav (Godot-friendly)")
    ap.add_argument("--overwrite", action="store_true",
                    help="Regenerate even if the output .wav already exists")
    ap.add_argument("--dry-run", action="store_true",
                    help="List what would be generated, don't synthesize")
    args = ap.parse_args()

    if not os.path.isdir(args.model):
        sys.exit(f"❌ Model not found: {args.model} (run voiceover/setup.sh)")
    if args.ogg and not shutil.which("ffmpeg"):
        sys.exit("❌ --ogg needs ffmpeg on PATH.")

    with open(args.manifest, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        sys.exit("❌ Manifest is empty (need a header row + lines).")

    required = {"character", "filename", "text"}
    missing = required - {c.strip() for c in rows[0].keys() if c}
    if missing:
        sys.exit(f"❌ Manifest missing column(s): {', '.join(sorted(missing))}")

    ok = skipped = failed = 0
    for n, row in enumerate(rows, 1):
        character = (row.get("character") or "").strip()
        filename = (row.get("filename") or "").strip()
        text = (row.get("text") or "").strip()
        emotion = (row.get("emotion") or "").strip()
        if not (character and filename and text):
            print(f"  [{n}] ⚠️  skipped (missing character/filename/text)")
            skipped += 1
            continue

        wav, transcript = resolve_voice(args.voices_dir, character, emotion)
        if not wav:
            tag = f"{character}.{emotion}" if emotion else character
            print(f"  [{n}] ⚠️  no voice clip for '{tag}' in {args.voices_dir} — skipped")
            skipped += 1
            continue

        out_dir = os.path.join(args.out_dir, character)
        os.makedirs(out_dir, exist_ok=True)
        out_wav = os.path.join(out_dir, f"{filename}.wav")

        if os.path.exists(out_wav) and not args.overwrite:
            print(f"  [{n}] ⏭️  exists: {out_wav}")
            skipped += 1
            continue

        label = f"{character}/{filename}" + (f" ({emotion})" if emotion else "")
        print(f"  [{n}] 🎙️  {label}: {text[:45]}")
        if args.dry_run:
            ok += 1
            continue

        cmd = [
            "dots.tts",
            "--model-name-or-path", args.model,
            "--text", text,
            "--prompt-audio", wav,
            "--output", out_wav,
            "--num-steps", str(args.steps),
            "--guidance-scale", str(args.guidance),
        ]
        if transcript:
            cmd += ["--prompt-text", transcript]

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            print(f"        ❌ synth failed (exit {e.returncode})")
            failed += 1
            continue

        if args.ogg:
            out_ogg = os.path.join(out_dir, f"{filename}.ogg")
            subprocess.run(
                ["ffmpeg", "-y", "-i", out_wav, "-c:a", "libvorbis", "-q:a", "5", out_ogg],
                check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        ok += 1

    print(f"\n✅ Done — {ok} generated, {skipped} skipped, {failed} failed → {args.out_dir}/")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
