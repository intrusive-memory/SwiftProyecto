---
type: reference
name: CLI Reference
description: Complete proyecto CLI command reference
---

# proyecto CLI

The `proyecto` CLI uses local LLM inference (via Foundation Models) to analyze directories and generate PROJECT.md files with appropriate metadata.

## Installation

**Homebrew (Recommended):**
```bash
brew tap intrusive-memory/tap
brew install proyecto
proyecto --version
```

**Build from Source:**
```bash
make install  # Debug build
make release  # Release build
./bin/proyecto --version
```

## Commands

### `proyecto init` (default)

Analyzes a directory and generates PROJECT.md metadata using local LLM inference.

```bash
# Analyze current directory
proyecto init

# Analyze specific directory
proyecto init /path/to/podcast

# Override author field
proyecto init --author "Jane Doe"

# Update existing PROJECT.md (preserves created, body, hooks)
proyecto init --update

# Force overwrite existing PROJECT.md
proyecto init --force

# Quiet mode
proyecto init --quiet
```

**Options:**
- `directory` (argument): Directory to analyze (default: current directory)
- `--author`: Override the author field (skip LLM detection)
- `--update`: Update existing PROJECT.md, preserving created date, body content, and hooks
- `--force`: Completely overwrite existing PROJECT.md
- `--quiet, -q`: Suppress progress output

**Model**: Uses the canonical Qwen2.5 7B Instruct model defined in `ModelManager.swift`. To use a different model, update the `LanguageModel` constant and rebuild the CLI.

**Behavior with existing PROJECT.md:**
- Default: Error if PROJECT.md exists (prevents accidental overwrites)
- `--force`: Completely replace existing PROJECT.md
- `--update`: Preserve created date, body content, and hooks; update other fields

### `proyecto download`

Downloads the Qwen2.5 7B LLM model from SwiftAcervo CDN for local inference. Model is cached locally for use by `proyecto init` and all projects using Foundation Models.

```bash
# Download Qwen2.5 7B model from CDN
proyecto download

# Force re-download (validates and re-downloads all files)
proyecto download --force

# Quiet mode (suppress progress)
proyecto download --quiet
```

**Options:**
- `--force`: Force re-download even if model exists, verifying all checksums
- `--quiet, -q`: Suppress progress output

**Model Details:**
- **Name**: Qwen2.5 7B Instruct (4-bit quantized)
- **Size**: ~4 GB
- **Location**: Managed by SwiftAcervo (typically `~/Library/Group Containers/group.intrusive-memory.models/SharedModels/mlx-community_Qwen2.5-7B-Instruct-4bit/`)
- **Checksum Verification**: All files verified with SHA-256 after download
- **Capability**: 128K context window, excellent instruction following, minimal hallucination

**Note**: The model is downloaded from SwiftAcervo CDN (Cloudflare R2) for reliable validation and checksumming.

### `proyecto migrate`

Migrates a legacy PROJECT.md to the current schema (v5). Today that means one thing: a legacy `cast:` block is moved into `CAST.md` — via `reparto import`, the sanctioned CAST.md writer — and PROJECT.md is rewritten without it, stamped `schemaVersion: 5`.

Requires the `reparto` binary: `brew install intrusive-memory/tap/reparto`.

```bash
# Migrate PROJECT.md in current directory
proyecto migrate

# Migrate a specific project
proyecto migrate /path/to/show

# Report what would happen, write nothing
proyecto migrate --dry-run

# Let reparto overwrite an existing CAST.md
proyecto migrate --force
```

**Options:**
- `path` (argument): Project directory or PROJECT.md path (default: current directory)
- `--dry-run`: Verify and report without writing anything
- `--force`: Overwrite an existing CAST.md (forwarded to `reparto import`)
- `--quiet, -q`: Suppress non-error output

**Data safety**: PROJECT.md is only rewritten *after* the transfer is verified — the import must succeed, the produced CAST.md must pass `reparto validate`, and every character from the legacy block must be present in it. A `PROJECT.md.bak` backup is written first and the rewrite is surgical (only the `cast:` span and the `schemaVersion:` line change). Any failure or refusal — `reparto` not installed, `CAST.md` already exists (the auto path never passes `--force`), or a season-level `cast:` block — leaves PROJECT.md byte-for-byte untouched.

`proyecto init --update` and `proyecto generate-project` run this migration automatically first, and abort their rewrite if it cannot complete. `proyecto validate` warns about a legacy `cast:` block but never mutates.

**Removed command**: `proyecto roles` (screenplay character extraction) was removed in 5.0.0 along with the rest of the cast surface — cast tooling lives in the `reparto` CLI ([SwiftReparto](https://github.com/intrusive-memory/SwiftReparto)).

## Iterative LLM Architecture

The `proyecto init` command uses an **iterative LLM approach** with 8 focused queries via Foundation Models:

**Sections Queried (in order):**
1. **Title** - Analyzes folder name, files, README for project title
2. **Author** - Checks git config, README, file metadata for author
3. **Description** - Generates 1-2 sentence description based on title and structure
4. **Genre** - Categorizes project (Philosophy, Education, Drama, Sci-Fi, etc.)
5. **Tags** - Generates 3-5 relevant tags based on title, description, genre
6. **Season** - Detects season numbers from folder/file patterns
7. **Episodes** - Counts episode files (*.fountain, *.fdx, etc.)
8. **Config** - Suggests episodesDir, audioDir, filePattern, exportFormat

**Benefits:**
- Smaller, focused prompts improve LLM accuracy
- Real-time progress visibility (`[Title] ✓ Title: My Project`)
- Better fault tolerance (retry individual sections)
- Context building (later sections reference earlier results)
- Successfully handles large projects (tested with 366 episodes)

**Example Output:**
```
[Title] Analyzing directory structure...
[Title] Querying LLM for Title...
[Title] ✓ Title: Space Exploration Podcast
[Author] Using author override: Tom Stovall
[Description] Querying LLM for Description...
[Description] ✓ Description: A science fiction podcast series...
[Genre] ✓ Genre: Science Fiction
[Tags] ✓ Tags: space, sci-fi, podcast, adventure
[Season] ✓ Season: 1
[Episodes] ✓ Episodes: 12
[Generation Config] ✓ Generation Config: episodesDir=episodes...
```
