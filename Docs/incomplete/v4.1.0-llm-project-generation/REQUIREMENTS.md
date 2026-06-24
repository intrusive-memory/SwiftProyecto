---
type: doc
name: REQUIREMENTS — v4.1.0 LLM-Based PROJECT.md Auto-Generation
description: Requirements for automatic PROJECT.md generation using Claude API
status: draft
created: 2026-06-23
---

# REQUIREMENTS — SwiftProyecto v4.1.0 LLM-Based PROJECT.md Auto-Generation

## Problem Statement

Users currently must manually create and maintain PROJECT.md files for content projects. This is error-prone, tedious, and requires understanding of the v4.x schema. The opportunity: use Claude API to analyze a project directory structure and **automatically generate valid v4.x PROJECT.md files** with reasonable defaults, cast lists, and metadata extraction.

**Desired outcome**: `proyecto generate-project` command that:
1. Analyzes project directory structure (episodes, assets, metadata)
2. Calls Claude API to understand project intent and organization
3. Generates a valid, well-formed v4.x PROJECT.md file
4. Requires minimal user input (ideally just project path + basic metadata)

---

## Scope

### In Scope (v4.1.0)

**Core Features**:
- [ ] `proyecto generate-project <path>` command
- [ ] Directory structure analysis (detect language/season patterns)
- [ ] Claude API integration for intelligent analysis
- [ ] Cast list extraction (from scripts, voice file names)
- [ ] Basic metadata inference (title, description, episode count, languages)
- [ ] v4.x schema compliance (output uses `schemaVersion: 4`)
- [ ] Multi-language detection
- [ ] TTS provider inference
- [ ] Episode path template generation
- [ ] Output validation before writing

### Out of Scope (defer to v4.2+)

- ❌ Automatic PROJECT.md updates/sync
- ❌ Web UI for interactive generation
- ❌ Batch generation across multiple projects
- ❌ Custom prompt templates
- ❌ Voice actor database integration
- ❌ Auto-generation of variant PROJECT.md files

---

## High-Level Features

### 1. Directory Structure Recognition
- Analyze project directories to detect language/season patterns
- Detect language codes (ISO 639-1, zh-CN, pt-BR, etc.)
- Infer season boundaries
- Suggest episode numbering schemes

### 2. Pluggable LLM Backend Integration
Multiple implementations:
- **Claude API** (macOS 26+, always available)
- **Apple Foundation Models** (macOS 27+, on-device)
- **SwiftBruja** (optional, specialized content analysis)

Fallback chain: SwiftBruja → Foundation Models → Claude

### 3. Cast List Inference
Extraction strategies (priority order):
1. Script analysis (Fountain format character headings)
2. File name patterns (e.g., `maestra_es.wav`)
3. Metadata files (CAST.md, CAST.csv)
4. Claude inference

### 4. TTS Provider Inference
- Scan audio directories for existing voice files
- Map file patterns to known providers (elevenlabs, google, polly)
- Ask Claude for provider recommendations

### 5. Episode Path Template Generation
- Scan actual episode file locations
- Detect language/season nesting
- Suggest template matching observed structure
- Validate template against real files

### 6. Metadata Inference
Extract: title, author, description, genre, languages, episode count, release date, tags

### 7. Multi-Language & Multi-Season Generation
Generate single master file (not variants):
- All languages in `languages[]`
- All seasons in `seasons[]`
- Single `episodePath` template covering all combos

### 8. Output Validation & Safety
- Parse as ProjectFrontMatter
- Run `isValid()` checks
- Verify required fields present
- Validate episode path template
- NEVER overwrite without `--force`
- Create backups before writes

---

## Success Criteria

### Functional
- [ ] `proyecto generate-project <path>` produces valid v4.x PROJECT.md
- [ ] Generated file passes `proyecto validate`
- [ ] All three backends generate valid output
- [ ] **[CRITICAL]** Multi-backend comparison on lingua-matra passes
- [ ] Cast extraction >80% accuracy
- [ ] Episode path templates match real structure
- [ ] Multi-language projects have all languages in `languages[]`
- [ ] Multi-season projects have all seasons in `seasons[]`
- [ ] Generated metadata intelligible and relevant

### User Experience
- [ ] Minimal user input required
- [ ] Clear progress feedback
- [ ] Helpful error messages
- [ ] Review and edit option before writing
- [ ] `--dry-run` mode to preview
- [ ] `--interactive` mode for guided generation

### Performance
- [ ] Directory scanning <5s for 1000+ files
- [ ] Claude API call <30s typical
- [ ] Total execution <60s
- [ ] Reasonable token usage (<5000 per project)

### Safety
- [ ] NEVER overwrites without `--force`
- [ ] Backup created before any write
- [ ] All validation errors reported
- [ ] Generated files reproducible
- [ ] No sensitive data in output

---

## Example Usage

```bash
# Preview with auto-detected backend
proyecto generate-project ./my-podcast --dry-run

# Interactive review before writing
proyecto generate-project ./my-podcast --interactive

# Auto-write (no review)
proyecto generate-project ./my-podcast --auto-write

# Force Claude backend
proyecto generate-project ./my-podcast --llm claude --dry-run

# Use Claude Opus for complex projects
proyecto generate-project ./my-podcast --llm claude --model opus

# Use SwiftBruja (with fallback)
proyecto generate-project ./my-podcast --llm bruja --dry-run
```

---

## Multi-Backend Comparison Test (CRITICAL)

**Test**: `test_generate_project_lingua_matra_all_backends`

**Purpose**: Validate all three backends on a real, complex project

**Process**:
1. For each backend (bruja, foundation, claude):
   - Run generation on `~/Projects/podcasts/lingua-matra`
   - Save to `/tmp/PROJECT-<backend>.md`
2. Validate each file:
   - Parses as ProjectFrontMatter
   - Passes `proyecto validate`
   - Has `schemaVersion: 4`
   - All required fields present
3. Compare vs reference:
   - Language codes correct (es, fr, it, pt, etc.)
   - Season count matches
   - Episode counts reasonable (~365/season)
   - Cast includes known characters
   - Title/description intelligible
4. Generate `BACKEND_COMPARISON_REPORT.md` with:
   - Side-by-side comparison
   - Quality scores (1-5) per backend
   - Recommendations

**Assertions** (all must pass):
- [ ] All backends generate valid v4.x PROJECT.md
- [ ] ≥2 backends detect all languages
- [ ] ≥2 backends detect season structure
- [ ] ≥1 backend generates reasonable cast
- [ ] No crashes or timeouts
- [ ] Files reproducible

---

## Dependencies

### Required
- v4.0.0 complete
- Swift 6.2+
- ProcessInfo (OS detection)

### Backend-Specific
- Claude: URLSession, API access
- Foundation Models: MLX/CoreML (macOS 27+)
- SwiftBruja: SwiftBruja package (optional)

---

## Timeline

- **Phase 1** (Backend Abstraction): 6-8 hours
- **Phase 2** (Claude Backend): 8 hours
- **Phase 3** (Foundation Models): 10 hours
- **Phase 3b** (SwiftBruja, optional): 6-8 hours
- **Phase 4** (Directory Analysis): 6-8 hours
- **Phase 5** (CLI): 4 hours
- **Phase 6** (Testing & Docs): 10-12 hours

**Total**: ~52-66 hours (~11-15 sorties)

---

## References

- v4.0.0 EXECUTION_PLAN
- PROJECT_MD_REFERENCE_v4.md
- Claude API: https://docs.anthropic.com
