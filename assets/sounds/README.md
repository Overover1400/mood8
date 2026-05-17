# Mood8 Sound Library

Drop the ten MP3 files below into this folder. Until they're present, the
app boots normally and `SfxService` silently skips the missing ones — no
crashes, no errors visible to the user.

## Vibe

Calming / zen. Tibetan bowls, soft water drops, wind chimes, breath sounds.
Think *meditation app*, not video game. Each clip should be **0.5–2 seconds**
and master to roughly **-14 LUFS** so playback at 30–70% volume never
startles.

## Required files

| Filename | Trigger | Suggested character | Target volume |
|---|---|---|---|
| `check_in_success.mp3` | Save daily check-in | Soft singing-bowl tap + brief shimmer | 0.55 |
| `habit_complete.mp3` | Toggle habit done | Quick water-droplet plink | 0.50 |
| `routine_done.mp3` | Mark routine complete | Wind-chime cluster (3 notes) | 0.55 |
| `streak_milestone.mp3` | Streak hits 3 / 7 / 30 / 100 / 365 | Warm bell swell + breath | 0.75 |
| `onboarding_step.mp3` | Advance onboarding step | Single soft chime | 0.40 |
| `onboarding_finish.mp3` | Onboarding completion | Bell + airy pad release | 0.80 |
| `ai_message.mp3` | AI Coach finishes a reply | Subtle pluck / pad note | 0.45 |
| `insight_discovered.mp3` | New insight surfaced | Twinkle + soft chime | 0.55 |
| `tab_switch.mp3` | Bottom-nav tab change | Whisper-quiet UI tick | 0.30 |
| `error_gentle.mp3` | Save/network failure | Low warm "no" — never harsh | 0.35 |

## Encoding

- Format: **MP3** (44.1 kHz, mono is fine, 128 kbps+ stereo also OK)
- Filenames must match exactly (case-sensitive)
- Keep payload under ~50 kB per file when possible

## License

Use royalty-free sources (Freesound CC0, Pixabay, your own recordings).
Add attribution lines here if a clip requires it.
