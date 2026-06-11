# Character voices for batch generation

Put your reference clips here (or in `~/.config/voiceover/voices/`, the default
the batch tool looks in). One short, clean clip *defines* a character's voice.

## Layout

```
voices/
  guard.wav            # neutral reference for "guard"
  guard.txt            # exact transcript of guard.wav
  guard.angry.wav      # optional emotion variant
  guard.angry.txt
  npc_merchant.wav
  npc_merchant.txt
  narrator.wav
  narrator.txt
```

- `<character>.wav` — the default voice for that character.
- `<character>.<emotion>.wav` — used when a manifest row's `emotion` column
  matches. Falls back to `<character>.wav` if the variant is missing.
- `<character>.txt` — the exact transcript of the clip (strongly recommended;
  it improves clone fidelity).

## Recording tips for game voices

- 5–15s, mono `.wav`, one speaker, no music/noise.
- **Match the performance to the character & emotion.** dots.tts copies the
  *tone* of the reference. An angry-variant clip should actually sound angry.
- Keep a neutral base clip per character, add emotion variants as needed
  (angry / hurt / happy / whisper).
- Grunts, screams, death sounds: use recorded SFX, not TTS — it's weak at
  non-verbal audio.

## Generate

```bash
voiceover-batch ../manifest.example.csv --out-dir game_audio --ogg
```

Output lands in `game_audio/<character>/<filename>.wav` (and `.ogg` with
`--ogg`), ready to import into Godot.
