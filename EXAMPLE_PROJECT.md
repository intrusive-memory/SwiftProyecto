---
type: project
title: Podcast Meditations: Mindfulness and Self-Care
author: Tom Stovall
created: 2025-01-25T00:00:00Z
description: The "Podcast Meditations: Mindfulness and Self-Care" project is a compilation of mindfulness-focused podcast episodes designed to promote mental well-bedependent care. It includes assets, episode scripts, and various files organized into directories for easy navigation and content management.
season: 1
episodes: 365
genre: Documentary
tags: [mindfulness, self-care, mental health, meditation, well-being]
episodesDir: episodes
audioDir: audio
filePattern: "*.fountain"
exportFormat: m4a
cast:
  - character: MARCUS AURELIUS
    actor: Tom Stovall
    gender: M
    voices:
      - apple://en-US/Aaron
  - character: NARRATOR
    actor: Jason Manino
    gender: M
    voices:
      - apple://en-US/Daniel
  - character: POETIC VOICE
    actor: Sarah Mitchell
    gender: F
    voices:
      - apple://en-US/Samantha
---

# Meditations Podcast

A year-long journey through the timeless wisdom of Marcus Aurelius.

## About

Marcus Aurelius (121-180 CE) was Roman Emperor from 161 to 180 CE and a Stoic philosopher. His personal writings, known as "Meditations," were never intended for publication but have become one of the most influential works of philosophy in Western history.

## Format

Each episode presents a reading from the Meditations, offering daily reflections on virtue, duty, mortality, and the nature of the self.

## Characters

- **MARCUS AURELIUS** - The narrator, voiced as the Emperor himself
- **NARRATOR** - Contextual introductions and transitions
- **POETIC VOICE** - Lyrical interpretations of key passages

## Production

Audio produced with Produciesta using Apple premium voices.

## Assets

All podcast branding assets are located in the `assets/` directory:

| File | Dimensions | Usage |
|------|------------|-------|
| `meditations-logo.png` | 2048×2048 | Master logo (PNG with transparency) |
| `podcast-artwork.jpg` | 2048×2048 | Podcast feed artwork (Apple Podcasts, Spotify, etc.) |
| `apple-touch-icon.png` | 180×180 | iOS home screen icon |
| `favicon.ico` | 16×16, 32×32 | Website favicon |

### Regenerating Assets

To regenerate derivative assets from the master logo:

```bash
cd assets
magick meditations-logo.png -quality 90 podcast-artwork.jpg
magick meditations-logo.png -resize 180x180 apple-touch-icon.png
magick meditations-logo.png -resize 16x16 favicon-16.png
magick meditations-logo.png -resize 32x32 favicon-32.png
magick favicon-16.png favicon-32.png favicon.ico
rm favicon-16.png favicon-32.png
```

## Batch Audio Generation

To generate audio for all episodes, run from the repository root:

```bash
./scripts/batch.sh
```

### Options

- `--skip-existing` - Skip episodes that already have audio files
- `--resume-from N` - Resume processing from episode number N
- `--release` - Use installed Produciesta app instead of Xcode build

### Examples

```bash
# Process all episodes
./scripts/batch.sh

# Skip episodes that already have audio
./scripts/batch.sh --skip-existing

# Resume from episode 50
./scripts/batch.sh --resume-from 50
```
