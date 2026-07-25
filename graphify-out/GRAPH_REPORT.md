# Graph Report - .  (2026-07-25)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1682 nodes · 2724 edges · 93 communities (63 shown, 30 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 139 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `17e37c79`
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
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Project File Reference|Project File Reference]]
- [[_COMMUNITY_Front Matter Settings Extension|Front Matter Settings Extension]]
- [[_COMMUNITY_Foundation Models Integration|Foundation Models Integration]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Document Context Type|Document Context Type]]
- [[_COMMUNITY_Community 49|Community 49]]
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
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 72|Community 72]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 81|Community 81]]
- [[_COMMUNITY_Community 82|Community 82]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]
- [[_COMMUNITY_Community 88|Community 88]]
- [[_COMMUNITY_Community 89|Community 89]]
- [[_COMMUNITY_Community 90|Community 90]]
- [[_COMMUNITY_Community 91|Community 91]]
- [[_COMMUNITY_Community 92|Community 92]]

## God Nodes (most connected - your core abstractions)
1. `ProjectMarkdownParserTests` - 56 edges
2. `ProjectMarkdownParser` - 47 edges
3. `ProjectWindowIntegrationTests` - 41 edges
4. `CastMemberTests` - 39 edges
5. `ProjectFrontMatterTests` - 39 edges
6. `GitRepositoryFileSource` - 35 edges
7. `ProjectModelTests` - 32 edges
8. `DirectoryFileSource` - 31 edges
9. `ProjectWindowTests` - 31 edges
10. `FilePatternTests` - 29 edges

## Surprising Connections (you probably didn't know these)
- `ProjectFrontMatter` --semantically_similar_to--> `PROJECT.md Format`  [EXTRACTED] [semantically similar]
  Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift → Docs/PROJECT_MD_REFERENCE.md
- `ProjectMarkdownParser` --references--> `PROJECT.md Format`  [EXTRACTED]
  Tests/SwiftProyectoTests/ProjectMarkdownParserTests.swift → Docs/PROJECT_MD_REFERENCE.md
- `ProjectService` --uses--> `FileSource Protocol (Abstraction)`  [EXTRACTED]
  Tests/SwiftProyectoTests/ProjectServiceTests.swift → Docs/CORE_ARCHITECTURE.md
- `ProjectService` --shares_data_with--> `ProjectFile Data Model`  [EXTRACTED]
  Tests/SwiftProyectoTests/ProjectServiceTests.swift → Docs/REQUIREMENTS_ReusableProjectWindow.md
- `CastMember Unit Tests` --documents--> `CastMember - Character-to-Voice Mapping`  [EXTRACTED]
  Tests/SwiftProyectoTests/CastMemberTests.swift → Docs/PROJECT_MD_REFERENCE.md

## Import Cycles
- None detected.

## Communities (93 total, 30 thin omitted)

### Community 0 - "Project File Service"
Cohesion: 0.06
Nodes (37): ByteCountFormatter, ProjectModel, UUID, EdgeInsets, Font, ProjectWindow, ProjectFile, String (+29 more)

### Community 1 - "Markdown Parser Tests"
Cohesion: 0.07
Nodes (26): AnyCodable, CastMember, FilePattern, Multi-Season/Multi-Language Schema (v4.0.0), ProjectFrontMatter, ProjectMarkdownParser, Any, AnyCodable (+18 more)

### Community 2 - "Front Matter Tests"
Cohesion: 0.05
Nodes (19): FileNode, ProjectModel, Bool, Hasher, Int, ProjectFileReference, ProjectModel, String (+11 more)

### Community 3 - "Git Repository File Source"
Cohesion: 0.07
Nodes (27): FileManager, FileSource Protocol (Abstraction), ProjectService, ProjectError, bookmarkCreationFailed, bookmarkResolutionFailed, fileNotFound, noBookmarkData (+19 more)

### Community 4 - "PROJECT.md Discovery"
Cohesion: 0.08
Nodes (8): ProjectFileContentLoaderTests, ProjectWindowPlatformLayoutTests, ProjectWindowTests, ProjectWindow, ProjectFile, String, URL, UUID

### Community 6 - "File Tree Structure"
Cohesion: 0.05
Nodes (6): OtherAppSettings, ProjectFrontMatterTests, TestAppSettings, Bool, Int, String

### Community 7 - "Security-Scoped Bookmark Management"
Cohesion: 0.07
Nodes (13): Data, ProjectFileContents, ProjectFileTests, Bool, Date, ProjectFile, String, Bool (+5 more)

### Community 8 - "Markdown Parser Core"
Cohesion: 0.09
Nodes (4): ProjectWindowIntegrationTests, ProjectFile, String, URL

### Community 9 - "Cast Member Tests"
Cohesion: 0.09
Nodes (17): PROJECT.md Discovery Algorithm, ProjectDiscovery, CastMember, String, URL, makeProjectMdContent(), makeTestProject(), ProjectDiscoveryCastReadingTests (+9 more)

### Community 10 - "Batch File Iterator"
Cohesion: 0.09
Nodes (26): AudioFormat, Chapter, Codable, Equatable, ExportSettings, GenerationSettings, AppFrontMatterSettings, TTSConfig (+18 more)

### Community 11 - "File Source Error Handling"
Cohesion: 0.08
Nodes (11): GitRepositoryFileSource, Data, Date, DiscoveredFile, FileSourceType, Set, String, URL (+3 more)

### Community 12 - "Project Model Tests"
Cohesion: 0.08
Nodes (12): FileSource, DirectoryFileSource, Data, Date, DiscoveredFile, FileSourceType, Set, String (+4 more)

### Community 13 - "File Pattern Tests"
Cohesion: 0.09
Nodes (27): Iterative LLM-Based Generation, CustomStringConvertible, FoundationModels, DirectoryAnalyzer, ExpressibleByArrayLiteral, ExpressibleByStringLiteral, FilePattern, multiple (+19 more)

### Community 14 - "Release Workflow"
Cohesion: 0.08
Nodes (40): Audio Player Handler, BackendRegistry (LLM Backend Discovery), CastExtractor (Character Discovery), Final Draft XML Format, FileAction Enum Model, FileLoadingState Enum Model, FileTreeView Component, FileTypeHandler Model (+32 more)

### Community 16 - "Bookmark Manager Tests"
Cohesion: 0.09
Nodes (23): DateFormatter, Error, Identifiable, FileTypeHandler, ProjectFile, LoadError, invalidEncoding, missingFrontMatter (+15 more)

### Community 17 - "Service Abstractions"
Cohesion: 0.12
Nodes (19): FileActionCallback, FileSelectionCallback, ProjectFile, ProjectWindow, ProjectDetailPane, AnyView, Bool, CGFloat (+11 more)

### Community 18 - "Iterative LLM Generation"
Cohesion: 0.11
Nodes (12): ProjectFileDiscoveryIntegrationTests, ProjectFileDiscovery, Bool, ProjectFile, Set, String, URL, Bool (+4 more)

### Community 19 - "App Settings Tests"
Cohesion: 0.07
Nodes (3): ProjectModelTests, ModelContainer, ModelContext

### Community 20 - "File Reference Tests"
Cohesion: 0.11
Nodes (14): Bool, Error, ProjectModel, Set, String, URL, ElementProgressState, GuionDocumentModel (+6 more)

### Community 22 - "CLI Validation Tests"
Cohesion: 0.12
Nodes (15): AudioPlayerController, AVPlayer, Double, Float, NSObject, NSObjectProtocol, ObservableObject, Any (+7 more)

### Community 23 - "Documentation Examples"
Cohesion: 0.18
Nodes (17): FileRevealing, NSWorkspace, ProjectFileActionError, fileNotFound, permissionDenied, underlying, ProjectFileActionHandler, ProjectFileActionResult (+9 more)

### Community 24 - "Model Container Factory"
Cohesion: 0.08
Nodes (4): ProjectServiceTests, ModelContainer, ModelContext, URL

### Community 26 - "Bookmark Error Handling"
Cohesion: 0.10
Nodes (24): CastMember - Character-to-Voice Mapping, DirectoryFileSource - Local Directory File Discovery, FileNode - Hierarchical File Tree Structure, FileSource Protocol - Pluggable File Discovery, Gender Enum - M, F, NB, NS Character Gender Specification, GitRepositoryFileSource - Git Repository Support, ProjectDiscovery - Locate PROJECT.md Files, ProjectMarkdownParser - YAML Front Matter Parser (+16 more)

### Community 27 - "Foundation Model Manager"
Cohesion: 0.15
Nodes (12): Config, AppFrontMatterSettingsTests, ComplexTestSettings, Config, SimpleTestSettings, Theme, dark, light (+4 more)

### Community 28 - "SwiftData Container Factory"
Cohesion: 0.10
Nodes (3): ProjectFileReferenceTests, ModelContainer, ModelContext

### Community 29 - "Audio Export Settings"
Cohesion: 0.21
Nodes (12): CGSize, FileTypeHandler, DefaultHandlers, AnyView, ProjectFile, String, URL, CGFloat (+4 more)

### Community 30 - "Project Data Model"
Cohesion: 0.24
Nodes (9): ParseBatchConfig, ParseBatchConfigError, invalidProjectPath, projectMdNotFound, ProjectModel, Bool, ParseBatchConfig, String (+1 more)

### Community 31 - "File Pattern Type"
Cohesion: 0.19
Nodes (3): ProjectFileDiscoveryTests, String, URL

### Community 32 - "Document Context Tests"
Cohesion: 0.20
Nodes (13): YAML Front Matter Parsing, DynamicCodingKey, ProjectFrontMatter, AnyCodable, Bool, CastMember, Date, Decoder (+5 more)

### Community 33 - "File Source Protocol"
Cohesion: 0.22
Nodes (14): Color, FileTreeNode, Binding, Bool, FileAction, ProjectFile, Set, String (+6 more)

### Community 34 - "SwiftProyecto Tests"
Cohesion: 0.15
Nodes (17): DiscoveredFile, FileSource, FileSourceError, fileNotFound, invalidPath, notGitRepository, permissionDenied, FileSourceType (+9 more)

### Community 35 - "YAML Parsing Tests"
Cohesion: 0.22
Nodes (4): Int32, ProyectoCLIValidateTests, String, URL

### Community 36 - "Model Download Integration"
Cohesion: 0.17
Nodes (4): ParseBatchConfigTests, Int, String, URL

### Community 37 - "Character Voice Mapping"
Cohesion: 0.12
Nodes (14): Character-to-Voice Mapping Pattern, CaseIterable, CastMember, voices, Gender, female, male, nonBinary (+6 more)

### Community 38 - "Type-Erased Codable"
Cohesion: 0.11
Nodes (15): Hashable, FileAction, custom, delete, reload, showInFinder, FileLoadingState, error (+7 more)

### Community 39 - "Directory Analysis"
Cohesion: 0.11
Nodes (18): KnownCodingKeys, audioDir, author, cast, created, description, episodes, episodesDir (+10 more)

### Community 41 - "AnyCodable Tests"
Cohesion: 0.12
Nodes (9): ComponentDescriptor, SwiftAcervo, LanguageModel, ModelManager, Bool, String, T, URL (+1 more)

### Community 42 - "Community 42"
Cohesion: 0.21
Nodes (12): Bool, Data, String, T, URL, BookmarkError, accessDenied, creationFailed (+4 more)

### Community 43 - "Community 43"
Cohesion: 0.20
Nodes (9): ValidationError, castListNotFound, episodeFileNotFound, missingCastList, mutuallyExclusive, ParseCommandArguments, Bool, String (+1 more)

### Community 44 - "Project File Reference"
Cohesion: 0.20
Nodes (3): ProjectMetadataTests, String, URL

### Community 45 - "Front Matter Settings Extension"
Cohesion: 0.25
Nodes (12): Binding, Bool, FileAction, Int, ProjectFile, ProjectMetadata, Set, String (+4 more)

### Community 46 - "Foundation Models Integration"
Cohesion: 0.22
Nodes (9): DocumentContext, ContainerError, cacheDirectoryCreationFailed, containerCreationFailed, projectRootDoesNotExist, ModelContainerFactory, Bool, ModelContainer (+1 more)

### Community 47 - "Community 47"
Cohesion: 0.15
Nodes (11): ProjectSection, author, config, description, episodes, genre, season, tags (+3 more)

### Community 48 - "Document Context Type"
Cohesion: 0.23
Nodes (12): Security-Scoped File Access Pattern, AsyncParsableCommand, BookmarkManager, ParsableCommand, InitCommand, ProyectoCLI, ValidateCommand, ProjectService (+4 more)

### Community 49 - "Community 49"
Cohesion: 0.18
Nodes (13): CastExtractor Component, CastExtractorTests, CastMember Data Model, CastMemberTests, Gender Enum (M, F, NB, NS), GuionParsedElementCollection, Operation Format Detente Mission, ProjectFrontMatter Data Model (+5 more)

### Community 50 - "Batch Processing Iterator"
Cohesion: 0.22
Nodes (8): LocalizedError, ValidationError, mutuallyExclusive, ParseBatchArguments, Bool, Int, String, URL

### Community 52 - "Settings Extension System"
Cohesion: 0.17
Nodes (4): AcervoDownloadIntegrationTests, ModelManagerBareDescriptorTests, SwiftProyectoTests, XCTestCase

### Community 53 - "SwiftProyecto Package"
Cohesion: 0.18
Nodes (5): OtherAppSettings, TestAppSettings, Bool, Int, String

### Community 55 - "Argument Parser"
Cohesion: 0.29
Nodes (6): AnyCodable, Bool, Data, Decoder, Encoder, T

### Community 56 - "Contributing Guidelines"
Cohesion: 0.42
Nodes (5): DirectoryAnalyzer, DirectoryContext, Int, String, URL

### Community 58 - "Bookmark Utilities"
Cohesion: 0.28
Nodes (9): BackendRegistry, ClaudeAPIBackend, DirectoryAnalyzer, FoundationModelsBackend, GenerateCommand CLI, LLMBackendProtocol, Operation MetaWing Mission, ProjectGeneratorService (+1 more)

### Community 59 - "Cast Discovery"
Cohesion: 0.22
Nodes (6): IteratorProtocol, ParseFileIterator, Sequence, Int, ParseBatchConfig, URL

### Community 60 - "Cast List Merging"
Cohesion: 0.25
Nodes (7): CodingKey, CodingKeys, actor, character, gender, voiceDescription, voicePrompt

### Community 61 - "Universal"
Cohesion: 0.46
Nodes (5): ParseBatchConfig, Bool, Int, String, URL

### Community 62 - "AGENTS Front Matter"
Cohesion: 0.39
Nodes (6): ProjectFileReference, Data, Date, ProjectModel, String, UUID

### Community 64 - "Gemini Integration"
Cohesion: 0.36
Nodes (6): ProyectoError, directoryNotFound, llmError, parseError, projectMdExists, projectMdNotFound

### Community 65 - "Performance Testing"
Cohesion: 0.25
Nodes (6): ProjectFileContentLoader, Bool, ProjectFile, ProjectFileContents, Set, UUID

### Community 66 - "Quick Start Guide"
Cohesion: 0.38
Nodes (3): ProjectFrontMatter, Bool, T

### Community 67 - "SwiftProyecto Logo"
Cohesion: 0.33
Nodes (6): SwiftAcervo Integration - CDN Model Distribution, Foundation Models Integration - On-Device LLM Inference, Iterative PROJECT.md Generation - 8 Focused Queries, proyecto CLI - LLM-Powered PROJECT.md Generation, Qwen2.5 7B Instruct (4-bit) - Canonical LLM Model, Migration from SwiftBruja to Apple Foundation Models

### Community 68 - "Discovered File Type"
Cohesion: 0.33
Nodes (5): DocumentContext, project, singleFile, Bool, URL

### Community 69 - "Community 69"
Cohesion: 0.67
Nodes (4): ParseBatchConfig - Resolved Batch Configuration, ParseFileIterator - Batch File Processing, PARSE Command Architecture and Iterator Pattern, Iterator Pattern - Separate Batch Logic from Single-File Generation

### Community 70 - "Community 70"
Cohesion: 0.50
Nodes (4): Package, sibling(), String, Version

### Community 72 - "Community 72"
Cohesion: 0.67
Nodes (3): AppFrontMatterSettings Protocol - Extension System, Extending PROJECT.md with App-Specific Settings, Extension System Design - Avoid Coupling Apps to SwiftProyecto

## Knowledge Gaps
- **285 isolated node(s):** `Package`, `String`, `Version`, `Bool`, `ParseBatchConfig` (+280 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **30 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ProjectMarkdownParser` connect `Markdown Parser Tests` to `Gemini Integration`, `Git Repository File Source`, `Directory File Source`, `File Tree Structure`, `Cast Member Tests`, `Batch File Iterator`, `Release Workflow`, `File Reference Tests`, `Project Data Model`?**
  _High betweenness centrality (0.181) - this node is a cross-community bridge._
- **Why does `ProjectView` connect `File Reference Tests` to `Project File Service`, `Git Repository File Source`, `Type-Erased Codable`?**
  _High betweenness centrality (0.147) - this node is a cross-community bridge._
- **Why does `ProjectService` connect `Git Repository File Source` to `Model Container Factory`, `File Reference Tests`, `Release Workflow`?**
  _High betweenness centrality (0.144) - this node is a cross-community bridge._
- **Are the 28 inferred relationships involving `ProjectMarkdownParser` (e.g. with `.from()` and `.parseBatchConfig()`) actually correct?**
  _`ProjectMarkdownParser` has 28 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Package`, `String`, `Version` to the rest of the system?**
  _299 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Project File Service` be split into smaller, more focused modules?**
  _Cohesion score 0.05819209039548023 - nodes in this community are weakly interconnected._
- **Should `Markdown Parser Tests` be split into smaller, more focused modules?**
  _Cohesion score 0.0734006734006734 - nodes in this community are weakly interconnected._