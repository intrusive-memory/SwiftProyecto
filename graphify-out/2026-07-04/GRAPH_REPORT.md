# Graph Report - .  (2026-07-04)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1087 nodes · 1656 edges · 65 communities (39 shown, 26 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 108 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cd537f19`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Project File Service|Project File Service]]
- [[_COMMUNITY_Markdown Parser Tests|Markdown Parser Tests]]
- [[_COMMUNITY_Front Matter Tests|Front Matter Tests]]
- [[_COMMUNITY_Git Repository File Source|Git Repository File Source]]
- [[_COMMUNITY_PROJECT.md Discovery|PROJECT.md Discovery]]
- [[_COMMUNITY_Directory File Source|Directory File Source]]
- [[_COMMUNITY_File Tree Structure|File Tree Structure]]
- [[_COMMUNITY_Security-Scoped Bookmark Management|Security-Scoped Bookmark Management]]
- [[_COMMUNITY_Markdown Parser Core|Markdown Parser Core]]
- [[_COMMUNITY_Cast Member Tests|Cast Member Tests]]
- [[_COMMUNITY_Batch File Iterator|Batch File Iterator]]
- [[_COMMUNITY_File Source Error Handling|File Source Error Handling]]
- [[_COMMUNITY_Project Model Tests|Project Model Tests]]
- [[_COMMUNITY_File Pattern Tests|File Pattern Tests]]
- [[_COMMUNITY_Release Workflow|Release Workflow]]
- [[_COMMUNITY_Project Service Tests|Project Service Tests]]
- [[_COMMUNITY_Bookmark Manager Tests|Bookmark Manager Tests]]
- [[_COMMUNITY_Service Abstractions|Service Abstractions]]
- [[_COMMUNITY_Iterative LLM Generation|Iterative LLM Generation]]
- [[_COMMUNITY_App Settings Tests|App Settings Tests]]
- [[_COMMUNITY_File Reference Tests|File Reference Tests]]
- [[_COMMUNITY_Batch Parse Configuration|Batch Parse Configuration]]
- [[_COMMUNITY_CLI Validation Tests|CLI Validation Tests]]
- [[_COMMUNITY_Documentation Examples|Documentation Examples]]
- [[_COMMUNITY_Model Container Factory|Model Container Factory]]
- [[_COMMUNITY_Settings Type Definitions|Settings Type Definitions]]
- [[_COMMUNITY_Bookmark Error Handling|Bookmark Error Handling]]
- [[_COMMUNITY_Foundation Model Manager|Foundation Model Manager]]
- [[_COMMUNITY_SwiftData Container Factory|SwiftData Container Factory]]
- [[_COMMUNITY_Audio Export Settings|Audio Export Settings]]
- [[_COMMUNITY_Project Data Model|Project Data Model]]
- [[_COMMUNITY_File Pattern Type|File Pattern Type]]
- [[_COMMUNITY_Document Context Tests|Document Context Tests]]
- [[_COMMUNITY_File Source Protocol|File Source Protocol]]
- [[_COMMUNITY_SwiftProyecto Tests|SwiftProyecto Tests]]
- [[_COMMUNITY_YAML Parsing Tests|YAML Parsing Tests]]
- [[_COMMUNITY_Model Download Integration|Model Download Integration]]
- [[_COMMUNITY_Character Voice Mapping|Character Voice Mapping]]
- [[_COMMUNITY_Type-Erased Codable|Type-Erased Codable]]
- [[_COMMUNITY_Directory Analysis|Directory Analysis]]
- [[_COMMUNITY_CI Workflow|CI Workflow]]
- [[_COMMUNITY_AnyCodable Tests|AnyCodable Tests]]
- [[_COMMUNITY_Project File Reference|Project File Reference]]
- [[_COMMUNITY_Front Matter Settings Extension|Front Matter Settings Extension]]
- [[_COMMUNITY_Foundation Models Integration|Foundation Models Integration]]
- [[_COMMUNITY_Document Context Type|Document Context Type]]
- [[_COMMUNITY_Batch Processing Iterator|Batch Processing Iterator]]
- [[_COMMUNITY_Package Management|Package Management]]
- [[_COMMUNITY_Settings Extension System|Settings Extension System]]
- [[_COMMUNITY_SwiftProyecto Package|SwiftProyecto Package]]
- [[_COMMUNITY_File Pattern Configuration|File Pattern Configuration]]
- [[_COMMUNITY_Argument Parser|Argument Parser]]
- [[_COMMUNITY_Contributing Guidelines|Contributing Guidelines]]
- [[_COMMUNITY_Platform Enforcement|Platform Enforcement]]
- [[_COMMUNITY_Bookmark Utilities|Bookmark Utilities]]
- [[_COMMUNITY_Cast Discovery|Cast Discovery]]
- [[_COMMUNITY_Cast List Merging|Cast List Merging]]
- [[_COMMUNITY_Universal|Universal]]
- [[_COMMUNITY_AGENTS Front Matter|AGENTS Front Matter]]
- [[_COMMUNITY_Version Changelog|Version Changelog]]
- [[_COMMUNITY_Gemini Integration|Gemini Integration]]
- [[_COMMUNITY_Performance Testing|Performance Testing]]
- [[_COMMUNITY_Quick Start Guide|Quick Start Guide]]
- [[_COMMUNITY_SwiftProyecto Logo|SwiftProyecto Logo]]
- [[_COMMUNITY_Discovered File Type|Discovered File Type]]

## God Nodes (most connected - your core abstractions)
1. `ProjectMarkdownParserTests` - 56 edges
2. `ProjectMarkdownParser` - 40 edges
3. `CastMemberTests` - 39 edges
4. `ProjectFrontMatterTests` - 39 edges
5. `GitRepositoryFileSource` - 35 edges
6. `ProjectModelTests` - 32 edges
7. `DirectoryFileSource` - 31 edges
8. `FilePatternTests` - 29 edges
9. `Sendable` - 28 edges
10. `ProjectServiceTests` - 28 edges

## Surprising Connections (you probably didn't know these)
- `CastMember Unit Tests` --documents--> `CastMember - Character-to-Voice Mapping`  [EXTRACTED]
  Tests/SwiftProyectoTests/CastMemberTests.swift → Docs/PROJECT_MD_REFERENCE.md
- `ProjectMarkdownParser Unit Tests` --documents--> `ProjectMarkdownParser - YAML Front Matter Parser`  [EXTRACTED]
  Tests/SwiftProyectoTests/ProjectMarkdownParserTests.swift → AGENTS.md
- `ModelManager` --uses--> `SwiftAcervo`  [EXTRACTED]
  Sources/SwiftProyecto/Infrastructure/ModelManager.swift → Package.swift
- `Config` --implements--> `Sendable`  [EXTRACTED]
  Tests/SwiftProyectoTests/AppFrontMatterSettingsTests.swift → Sources/SwiftProyecto/Infrastructure/ModelManager.swift
- `Theme` --implements--> `Sendable`  [EXTRACTED]
  Tests/SwiftProyectoTests/AppFrontMatterSettingsTests.swift → Sources/SwiftProyecto/Infrastructure/ModelManager.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Character-to-Voice Casting System** — concept_castmember, concept_voice_providers, concept_gender_enum, concept_voice_description, concept_cast_discovery, concept_cast_merging [EXTRACTED 1.00]
- **File Discovery and Source Abstraction** — concept_filesource_abstraction, concept_directoryfilesource, concept_gitrepositoryfilesource, concept_projectservice [EXTRACTED 1.00]
- **LLM-Powered PROJECT.md Generation** — concept_proyecto_cli, concept_foundationmodels_integration, concept_iterative_generation, concept_qwen2_5_model, concept_acervo_integration [EXTRACTED 1.00]
- **Batch Audio Generation with Iterator Pattern** — concept_parse_batch_config, concept_parse_iterator_pattern [EXTRACTED 1.00]
- **PROJECT.md Format and Extension System** — concept_projectmd_format, concept_filepattern, concept_appfrontmattersettings, concept_agents_property [EXTRACTED 1.00]
- **Core SwiftProyecto Services** — concept_projectservice, concept_projectmarkdownparser, concept_projectdiscovery, concept_bookmarkmanager [EXTRACTED 1.00]
- **Agentic Project Discovery Pattern** — doc_swiftproyecto_overview, concept_projectmd_format, concept_projectservice, doc_agents_md [INFERRED 0.95]
- **PROJECT.md Generation Pipeline** — cli_proyectocli, cli_initcommand, cli_iterativeprojectgenerator, cli_directoryanalyzer, utility_projectmarkdownparser, model_projectfrontmatter [EXTRACTED 1.00]
- **YAML Metadata Representation** — model_projectfrontmatter, model_castmember, model_filepattern, model_ttsconfig, utility_projectmarkdownparser [EXTRACTED 1.00]
- **Project Lifecycle Management** — service_projectservice, service_projectdiscovery, infra_bookmarkmanager, model_projectmodel, model_projectfilereference [EXTRACTED 1.00]
- **LLM-Driven Generation System** — cli_iterativeprojectgenerator, cli_directoryanalyzer, cli_projectsection, cli_directorycontext, infra_modelmanager, dep_foundationmodels [EXTRACTED 1.00]
- **CLI Validation Pattern** — cli_proyectocli, cli_validatecommand, utility_projectmarkdownparser, model_projectfrontmatter [INFERRED 0.95]
- **CI/CD Release Automation** — workflow_ci, workflow_release, cli_proyectocli, infra_languagemodel [INFERRED 0.90]
- **File Discovery and Synchronization** — service_projectservice, service_projectdiscovery, model_projectfilereference, model_discoveredfile [EXTRACTED 1.00]
- **Cast and Character Voice System** — model_castmember, model_gender, rationale_casting_voices, model_projectfrontmatter [INFERRED 0.95]
- **Package Dependencies** — dep_swiftacervo, dep_universal, dep_argumentparser, dep_foundationmodels [EXTRACTED 1.00]

## Communities (65 total, 26 thin omitted)

### Community 0 - "Project File Service"
Cohesion: 0.08
Nodes (26): FileManager, ProjectService, ProjectError, bookmarkCreationFailed, bookmarkResolutionFailed, fileNotFound, noBookmarkData, projectAlreadyExists (+18 more)

### Community 2 - "Front Matter Tests"
Cohesion: 0.05
Nodes (6): OtherAppSettings, ProjectFrontMatterTests, TestAppSettings, Bool, Int, String

### Community 3 - "Git Repository File Source"
Cohesion: 0.08
Nodes (11): GitRepositoryFileSource, Data, Date, DiscoveredFile, FileSourceType, Set, String, URL (+3 more)

### Community 4 - "PROJECT.md Discovery"
Cohesion: 0.09
Nodes (17): PROJECT.md Discovery Algorithm, ProjectDiscovery, CastMember, String, URL, makeProjectMdContent(), makeTestProject(), ProjectDiscoveryCastReadingTests (+9 more)

### Community 5 - "Directory File Source"
Cohesion: 0.08
Nodes (11): FileSource, DirectoryFileSource, Data, Date, FileSourceType, Set, String, URL (+3 more)

### Community 6 - "File Tree Structure"
Cohesion: 0.07
Nodes (9): FileNode, Bool, Hasher, Int, ProjectFileReference, ProjectModel, String, UUID (+1 more)

### Community 7 - "Security-Scoped Bookmark Management"
Cohesion: 0.05
Nodes (50): Security-Scoped File Access Pattern, YAML Front Matter Parsing, AsyncParsableCommand, BookmarkManager, DynamicCodingKey, KnownCodingKeys, audioDir, author (+42 more)

### Community 8 - "Markdown Parser Core"
Cohesion: 0.10
Nodes (20): ProjectMarkdownParser, Any, AnyCodable, FilePattern, Int, ProjectFrontMatter, String, URL (+12 more)

### Community 10 - "Batch File Iterator"
Cohesion: 0.09
Nodes (20): IteratorProtocol, ParseBatchConfig, ValidationError, castListNotFound, episodeFileNotFound, missingCastList, mutuallyExclusive, ParseCommandArguments (+12 more)

### Community 11 - "File Source Error Handling"
Cohesion: 0.09
Nodes (17): FileSourceError, fileNotFound, invalidPath, notGitRepository, permissionDenied, LocalizedError, ValidationError, mutuallyExclusive (+9 more)

### Community 12 - "Project Model Tests"
Cohesion: 0.07
Nodes (3): ProjectModelTests, ModelContainer, ModelContext

### Community 15 - "Project Service Tests"
Cohesion: 0.08
Nodes (4): ProjectServiceTests, ModelContainer, ModelContext, URL

### Community 17 - "Service Abstractions"
Cohesion: 0.09
Nodes (25): CastMember - Character-to-Voice Mapping, DirectoryFileSource - Local Directory File Discovery, FileNode - Hierarchical File Tree Structure, FileSource Protocol - Pluggable File Discovery, Gender Enum - M, F, NB, NS Character Gender Specification, GitRepositoryFileSource - Git Repository Support, ProjectDiscovery - Locate PROJECT.md Files, ProjectMarkdownParser - YAML Front Matter Parser (+17 more)

### Community 18 - "Iterative LLM Generation"
Cohesion: 0.16
Nodes (17): Iterative LLM-Based Generation, FoundationModels, DirectoryAnalyzer, ProjectSection, GeneratorError, invalidConfigResponse, invalidNumberResponse, missingRequiredFields (+9 more)

### Community 19 - "App Settings Tests"
Cohesion: 0.15
Nodes (12): Config, AppFrontMatterSettingsTests, ComplexTestSettings, Config, SimpleTestSettings, Theme, dark, light (+4 more)

### Community 20 - "File Reference Tests"
Cohesion: 0.10
Nodes (3): ProjectFileReferenceTests, ModelContainer, ModelContext

### Community 21 - "Batch Parse Configuration"
Cohesion: 0.24
Nodes (9): ParseBatchConfig, ParseBatchConfigError, invalidProjectPath, projectMdNotFound, ProjectModel, Bool, ParseBatchConfig, String (+1 more)

### Community 22 - "CLI Validation Tests"
Cohesion: 0.22
Nodes (4): Int32, ProyectoCLIValidateTests, String, URL

### Community 23 - "Documentation Examples"
Cohesion: 0.17
Nodes (8): AudioFormat, Chapter, Double, Chapter, DocumentationExamplesTests, MyAppSettings, PodcastAppSettings, Bool

### Community 25 - "Settings Type Definitions"
Cohesion: 0.25
Nodes (6): ExportSettings, GenerationSettings, AppFrontMatterSettings, NestedSettings, VersionedSettings, UISettings

### Community 26 - "Bookmark Error Handling"
Cohesion: 0.21
Nodes (12): Bool, Data, String, T, URL, BookmarkError, accessDenied, creationFailed (+4 more)

### Community 27 - "Foundation Model Manager"
Cohesion: 0.12
Nodes (9): ComponentDescriptor, SwiftAcervo, LanguageModel, ModelManager, Bool, String, T, URL (+1 more)

### Community 28 - "SwiftData Container Factory"
Cohesion: 0.22
Nodes (9): DocumentContext, ContainerError, cacheDirectoryCreationFailed, containerCreationFailed, projectRootDoesNotExist, ModelContainerFactory, Bool, ModelContainer (+1 more)

### Community 29 - "Audio Export Settings"
Cohesion: 0.27
Nodes (10): Equatable, AudioFormat, aac, flac, mp3, ExportSettings, GenerationSettings, UISettings (+2 more)

### Community 30 - "Project Data Model"
Cohesion: 0.23
Nodes (10): ProjectModel, Bool, Data, Date, FileSource, FileSourceType, Int, ProjectFileReference (+2 more)

### Community 31 - "File Pattern Type"
Cohesion: 0.17
Nodes (10): CustomStringConvertible, ExpressibleByArrayLiteral, ExpressibleByStringLiteral, FilePattern, multiple, single, Bool, Decoder (+2 more)

### Community 33 - "File Source Protocol"
Cohesion: 0.21
Nodes (9): Codable, FileSource, FileSourceType, directory, gitRepository, packageBundle, TTSConfig, Sendable (+1 more)

### Community 34 - "SwiftProyecto Tests"
Cohesion: 0.29
Nodes (3): ModelManagerBareDescriptorTests, SwiftProyectoTests, XCTestCase

### Community 35 - "YAML Parsing Tests"
Cohesion: 0.18
Nodes (5): OtherAppSettings, TestAppSettings, Bool, Int, String

### Community 37 - "Character Voice Mapping"
Cohesion: 0.05
Nodes (41): Character-to-Voice Mapping Pattern, CaseIterable, CodingKey, DiscoveredFile, Hashable, Identifiable, Int64, CastMember (+33 more)

### Community 38 - "Type-Erased Codable"
Cohesion: 0.29
Nodes (6): AnyCodable, Bool, Data, Decoder, Encoder, T

### Community 39 - "Directory Analysis"
Cohesion: 0.42
Nodes (5): DirectoryAnalyzer, DirectoryContext, Int, String, URL

### Community 44 - "Project File Reference"
Cohesion: 0.39
Nodes (6): ProjectFileReference, Data, Date, ProjectModel, String, UUID

### Community 45 - "Front Matter Settings Extension"
Cohesion: 0.38
Nodes (3): ProjectFrontMatter, Bool, T

### Community 46 - "Foundation Models Integration"
Cohesion: 0.33
Nodes (6): SwiftAcervo Integration - CDN Model Distribution, Foundation Models Integration - On-Device LLM Inference, Iterative PROJECT.md Generation - 8 Focused Queries, proyecto CLI - LLM-Powered PROJECT.md Generation, Qwen2.5 7B Instruct (4-bit) - Canonical LLM Model, Migration from SwiftBruja to Apple Foundation Models

### Community 48 - "Document Context Type"
Cohesion: 0.33
Nodes (5): DocumentContext, project, singleFile, Bool, URL

### Community 50 - "Batch Processing Iterator"
Cohesion: 0.67
Nodes (4): ParseBatchConfig - Resolved Batch Configuration, ParseFileIterator - Batch File Processing, PARSE Command Architecture and Iterator Pattern, Iterator Pattern - Separate Batch Logic from Single-File Generation

### Community 51 - "Package Management"
Cohesion: 0.50
Nodes (4): Package, sibling(), String, Version

### Community 52 - "Settings Extension System"
Cohesion: 0.67
Nodes (3): AppFrontMatterSettings Protocol - Extension System, Extending PROJECT.md with App-Specific Settings, Extension System Design - Avoid Coupling Apps to SwiftProyecto

## Knowledge Gaps
- **192 isolated node(s):** `Package`, `String`, `Version`, `Bool`, `ParseBatchConfig` (+187 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **26 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Sendable` connect `File Source Protocol` to `Git Repository File Source`, `PROJECT.md Discovery`, `Character Voice Mapping`, `Directory File Source`, `File Tree Structure`, `Type-Erased Codable`, `Security-Scoped Bookmark Management`, `Batch File Iterator`, `File Source Error Handling`, `Directory Analysis`, `Document Context Type`, `App Settings Tests`, `Documentation Examples`, `Settings Type Definitions`, `Foundation Model Manager`, `Audio Export Settings`, `File Pattern Type`?**
  _High betweenness centrality (0.213) - this node is a cross-community bridge._
- **Why does `ProjectMarkdownParser` connect `Markdown Parser Core` to `Project File Service`, `Markdown Parser Tests`, `Front Matter Tests`, `PROJECT.md Discovery`, `Security-Scoped Bookmark Management`, `Batch Parse Configuration`, `Documentation Examples`, `Settings Type Definitions`, `Audio Export Settings`?**
  _High betweenness centrality (0.206) - this node is a cross-community bridge._
- **Why does `ProjectMarkdownParserTests` connect `Markdown Parser Tests` to `Markdown Parser Core`, `SwiftProyecto Tests`, `YAML Parsing Tests`?**
  _High betweenness centrality (0.174) - this node is a cross-community bridge._
- **Are the 27 inferred relationships involving `ProjectMarkdownParser` (e.g. with `.from()` and `.parseBatchConfig()`) actually correct?**
  _`ProjectMarkdownParser` has 27 INFERRED edges - model-reasoned connections that need verification._
- **Are the 21 inferred relationships involving `GitRepositoryFileSource` (e.g. with `.fileSource()` and `.testDiscoverAndRead_Integration()`) actually correct?**
  _`GitRepositoryFileSource` has 21 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Package`, `String`, `Version` to the rest of the system?**
  _205 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Project File Service` be split into smaller, more focused modules?**
  _Cohesion score 0.07686274509803921 - nodes in this community are weakly interconnected._