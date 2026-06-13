# Graph Report - .  (2026-06-12)

## Corpus Check
- 107 files · ~424,760 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1104 nodes · 1659 edges · 71 communities (46 shown, 25 thin omitted)
- Extraction: 93.5% EXTRACTED · 6.5% INFERRED · 0% AMBIGUOUS · INFERRED: 108 edges (avg confidence: 0.8)
- **Filtered:** Removed 3 workflow-related inferred edges + 1 CI/CD Release Automation hyperedge
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Project Service|Project Service]]
- [[_COMMUNITY_Parser Tests|Parser Tests]]
- [[_COMMUNITY_Front Matter Tests|Front Matter Tests]]
- [[_COMMUNITY_Git File Discovery|Git File Discovery]]
- [[_COMMUNITY_Project Discovery|Project Discovery]]
- [[_COMMUNITY_Directory File Source|Directory File Source]]
- [[_COMMUNITY_File Tree Structure|File Tree Structure]]
- [[_COMMUNITY_Project Metadata|Project Metadata]]
- [[_COMMUNITY_Markdown Parsing|Markdown Parsing]]
- [[_COMMUNITY_Cast Member Tests|Cast Member Tests]]
- [[_COMMUNITY_Iteratorprotocol System|Iteratorprotocol System]]
- [[_COMMUNITY_Localizederror System|Localizederror System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Arch System|Arch System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Directoryanalyzer System|Directoryanalyzer System]]
- [[_COMMUNITY_Config System|Config System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Extensions System|Extensions System]]
- [[_COMMUNITY_Int32 System|Int32 System]]
- [[_COMMUNITY_Audioformat System|Audioformat System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Asyncparsablecommand System|Asyncparsablecommand System]]
- [[_COMMUNITY_Sources System|Sources System]]
- [[_COMMUNITY_Componentdescriptor System|Componentdescriptor System]]
- [[_COMMUNITY_Documentcontext System|Documentcontext System]]
- [[_COMMUNITY_Equatable System|Equatable System]]
- [[_COMMUNITY_Models System|Models System]]
- [[_COMMUNITY_Customstringconvertible System|Customstringconvertible System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Codable System|Codable System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Filesource System|Filesource System]]
- [[_COMMUNITY_Codingkey System|Codingkey System]]
- [[_COMMUNITY_Models System|Models System]]
- [[_COMMUNITY_Proyecto System|Proyecto System]]
- [[_COMMUNITY_Proyecto System|Proyecto System]]
- [[_COMMUNITY_Swiftproyectotests System|Swiftproyectotests System]]
- [[_COMMUNITY_Caseiterable System|Caseiterable System]]
- [[_COMMUNITY_Hashable System|Hashable System]]
- [[_COMMUNITY_Models System|Models System]]
- [[_COMMUNITY_Extensions System|Extensions System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Filesource System|Filesource System]]
- [[_COMMUNITY_Services System|Services System]]
- [[_COMMUNITY_Proyecto System|Proyecto System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Package System|Package System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Swiftproyecto System|Swiftproyecto System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Dep System|Dep System]]
- [[_COMMUNITY_Doc System|Doc System]]
- [[_COMMUNITY_Doc System|Doc System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Concept System|Concept System]]
- [[_COMMUNITY_Dep System|Dep System]]
- [[_COMMUNITY_Doc System|Doc System]]
- [[_COMMUNITY_Doc System|Doc System]]
- [[_COMMUNITY_Doc System|Doc System]]
- [[_COMMUNITY_Doc System|Doc System]]
- [[_COMMUNITY_Doc System|Doc System]]
- [[_COMMUNITY_Image System|Image System]]
- [[_COMMUNITY_Model System|Model System]]
- [[_COMMUNITY_Model System|Model System]]
- [[_COMMUNITY_Model System|Model System]]

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
- **File Discovery and Synchronization** — service_projectservice, service_projectdiscovery, model_projectfilereference, model_discoveredfile [EXTRACTED 1.00]
- **Cast and Character Voice System** — model_castmember, model_gender, rationale_casting_voices, model_projectfrontmatter [INFERRED 0.95]
- **Package Dependencies** — dep_swiftacervo, dep_universal, dep_argumentparser, dep_foundationmodels [EXTRACTED 1.00]

## Communities (71 total, 25 thin omitted)

### Community 0 - "Project Service"
Cohesion: 0.08
Nodes (26): FileManager, ProjectService, ProjectError, bookmarkCreationFailed, bookmarkResolutionFailed, fileNotFound, noBookmarkData, projectAlreadyExists (+18 more)

### Community 2 - "Front Matter Tests"
Cohesion: 0.05
Nodes (6): OtherAppSettings, ProjectFrontMatterTests, TestAppSettings, Bool, Int, String

### Community 3 - "Git File Discovery"
Cohesion: 0.08
Nodes (11): GitRepositoryFileSource, Data, Date, DiscoveredFile, FileSourceType, Set, String, URL (+3 more)

### Community 4 - "Project Discovery"
Cohesion: 0.09
Nodes (16): ProjectDiscovery, CastMember, String, URL, makeProjectMdContent(), makeTestProject(), ProjectDiscoveryCastReadingTests, ProjectDiscoveryDirectoryTests (+8 more)

### Community 5 - "Directory File Source"
Cohesion: 0.08
Nodes (12): FileSource, DirectoryFileSource, Data, Date, DiscoveredFile, FileSourceType, Set, String (+4 more)

### Community 6 - "File Tree Structure"
Cohesion: 0.07
Nodes (9): FileNode, Bool, Hasher, Int, ProjectFileReference, ProjectModel, String, UUID (+1 more)

### Community 7 - "Project Metadata"
Cohesion: 0.08
Nodes (31): DynamicCodingKey, KnownCodingKeys, audioDir, author, cast, created, description, episodes (+23 more)

### Community 8 - "Markdown Parsing"
Cohesion: 0.10
Nodes (20): ProjectMarkdownParser, Any, AnyCodable, FilePattern, Int, ProjectFrontMatter, String, URL (+12 more)

### Community 10 - "Iteratorprotocol System"
Cohesion: 0.09
Nodes (20): IteratorProtocol, ParseBatchConfig, ValidationError, castListNotFound, episodeFileNotFound, missingCastList, mutuallyExclusive, ParseCommandArguments (+12 more)

### Community 11 - "Localizederror System"
Cohesion: 0.11
Nodes (12): LocalizedError, ValidationError, mutuallyExclusive, ParseBatchArguments, Bool, Int, String, URL (+4 more)

### Community 12 - "Swiftproyectotests System"
Cohesion: 0.07
Nodes (3): ProjectModelTests, ModelContainer, ModelContext

### Community 14 - "Arch System"
Cohesion: 0.10
Nodes (28): Character-to-Voice Mapping Pattern, Iterative LLM-Based Generation, Security-Scoped File Access Pattern, YAML Front Matter Parsing, DirectoryAnalyzer, DirectoryContext, InitCommand, IterativeProjectGenerator (+20 more)

### Community 15 - "Swiftproyectotests System"
Cohesion: 0.08
Nodes (4): ProjectServiceTests, ModelContainer, ModelContext, URL

### Community 17 - "Concept System"
Cohesion: 0.09
Nodes (25): CastMember - Character-to-Voice Mapping, DirectoryFileSource - Local Directory File Discovery, FileNode - Hierarchical File Tree Structure, FileSource Protocol - Pluggable File Discovery, Gender Enum - M, F, NB, NS Character Gender Specification, GitRepositoryFileSource - Git Repository Support, ProjectDiscovery - Locate PROJECT.md Files, ProjectMarkdownParser - YAML Front Matter Parser (+17 more)

### Community 18 - "Directoryanalyzer System"
Cohesion: 0.18
Nodes (15): DirectoryAnalyzer, ProjectSection, GeneratorError, invalidConfigResponse, invalidNumberResponse, missingRequiredFields, sectionFailed, IterativeProjectGenerator (+7 more)

### Community 19 - "Config System"
Cohesion: 0.15
Nodes (12): Config, AppFrontMatterSettingsTests, ComplexTestSettings, Config, SimpleTestSettings, Theme, dark, light (+4 more)

### Community 20 - "Swiftproyectotests System"
Cohesion: 0.10
Nodes (3): ProjectFileReferenceTests, ModelContainer, ModelContext

### Community 21 - "Extensions System"
Cohesion: 0.24
Nodes (9): ParseBatchConfig, ParseBatchConfigError, invalidProjectPath, projectMdNotFound, ProjectModel, Bool, ParseBatchConfig, String (+1 more)

### Community 22 - "Int32 System"
Cohesion: 0.22
Nodes (4): Int32, ProyectoCLIValidateTests, String, URL

### Community 23 - "Audioformat System"
Cohesion: 0.18
Nodes (7): AudioFormat, Chapter, Double, Chapter, DocumentationExamplesTests, MyAppSettings, PodcastAppSettings

### Community 25 - "Asyncparsablecommand System"
Cohesion: 0.18
Nodes (14): AsyncParsableCommand, ParsableCommand, InitCommand, ProyectoCLI, ProyectoError, directoryNotFound, llmError, parseError (+6 more)

### Community 26 - "Sources System"
Cohesion: 0.21
Nodes (12): Bool, Data, String, T, URL, BookmarkError, accessDenied, creationFailed (+4 more)

### Community 27 - "Componentdescriptor System"
Cohesion: 0.13
Nodes (7): ComponentDescriptor, ModelManager, Bool, String, T, URL, Void

### Community 28 - "Documentcontext System"
Cohesion: 0.22
Nodes (9): DocumentContext, ContainerError, cacheDirectoryCreationFailed, containerCreationFailed, projectRootDoesNotExist, ModelContainerFactory, Bool, ModelContainer (+1 more)

### Community 29 - "Equatable System"
Cohesion: 0.21
Nodes (12): Equatable, ExportSettings, GenerationSettings, ExportSettings, GenerationSettings, NestedSettings, UISettings, VersionedSettings (+4 more)

### Community 30 - "Models System"
Cohesion: 0.23
Nodes (10): ProjectModel, Bool, Data, Date, FileSource, FileSourceType, Int, ProjectFileReference (+2 more)

### Community 31 - "Customstringconvertible System"
Cohesion: 0.17
Nodes (10): CustomStringConvertible, ExpressibleByArrayLiteral, ExpressibleByStringLiteral, FilePattern, multiple, single, Bool, Decoder (+2 more)

### Community 33 - "Codable System"
Cohesion: 0.21
Nodes (9): Codable, AppFrontMatterSettings, TTSConfig, Sendable, String, AudioFormat, aac, flac (+1 more)

### Community 34 - "Swiftproyectotests System"
Cohesion: 0.17
Nodes (4): AcervoDownloadIntegrationTests, ModelManagerBareDescriptorTests, SwiftProyectoTests, XCTestCase

### Community 35 - "Swiftproyectotests System"
Cohesion: 0.18
Nodes (5): OtherAppSettings, TestAppSettings, Bool, Int, String

### Community 36 - "Filesource System"
Cohesion: 0.18
Nodes (10): FileSource, FileSourceError, fileNotFound, invalidPath, notGitRepository, permissionDenied, FileSourceType, directory (+2 more)

### Community 37 - "Codingkey System"
Cohesion: 0.20
Nodes (8): CodingKey, CodingKeys, actor, character, gender, voiceDescription, voicePrompt, voices

### Community 38 - "Models System"
Cohesion: 0.29
Nodes (6): AnyCodable, Bool, Data, Decoder, Encoder, T

### Community 39 - "Proyecto System"
Cohesion: 0.40
Nodes (5): DirectoryAnalyzer, DirectoryContext, Int, String, URL

### Community 40 - "Proyecto System"
Cohesion: 0.20
Nodes (9): ProjectSection, author, config, description, episodes, genre, season, tags (+1 more)

### Community 42 - "Caseiterable System"
Cohesion: 0.25
Nodes (7): CaseIterable, Gender, female, male, nonBinary, notSpecified, Decoder

### Community 43 - "Hashable System"
Cohesion: 0.25
Nodes (6): Hashable, Identifiable, CastMember, Bool, Encoder, Hasher

### Community 44 - "Models System"
Cohesion: 0.39
Nodes (6): ProjectFileReference, Data, Date, ProjectModel, String, UUID

### Community 45 - "Extensions System"
Cohesion: 0.38
Nodes (3): ProjectFrontMatter, Bool, T

### Community 46 - "Concept System"
Cohesion: 0.33
Nodes (6): SwiftAcervo Integration - CDN Model Distribution, Foundation Models Integration - On-Device LLM Inference, Iterative PROJECT.md Generation - 8 Focused Queries, proyecto CLI - LLM-Powered PROJECT.md Generation, Qwen2.5 7B Instruct (4-bit) - Canonical LLM Model, Migration from SwiftBruja to Apple Foundation Models

### Community 47 - "Filesource System"
Cohesion: 0.53
Nodes (5): DiscoveredFile, Int64, Bool, Date, UUID

### Community 48 - "Services System"
Cohesion: 0.33
Nodes (5): DocumentContext, project, singleFile, Bool, URL

### Community 49 - "Proyecto System"
Cohesion: 0.50
Nodes (3): Any, DirectoryContext, String

### Community 50 - "Concept System"
Cohesion: 0.67
Nodes (4): ParseBatchConfig - Resolved Batch Configuration, ParseFileIterator - Batch File Processing, PARSE Command Architecture and Iterator Pattern, Iterator Pattern - Separate Batch Logic from Single-File Generation

### Community 51 - "Package System"
Cohesion: 0.50
Nodes (4): Package, sibling(), String, Version

### Community 52 - "Concept System"
Cohesion: 0.67
Nodes (3): AppFrontMatterSettings Protocol - Extension System, Extending PROJECT.md with App-Specific Settings, Extension System Design - Avoid Coupling Apps to SwiftProyecto

## Knowledge Gaps
- **195 isolated node(s):** `Package`, `String`, `Version`, `Bool`, `ParseBatchConfig` (+190 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **25 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Sendable` connect `Codable System` to `Git File Discovery`, `Project Discovery`, `Directory File Source`, `File Tree Structure`, `Project Metadata`, `Iteratorprotocol System`, `Localizederror System`, `Config System`, `Audioformat System`, `Componentdescriptor System`, `Equatable System`, `Customstringconvertible System`, `Filesource System`, `Models System`, `Proyecto System`, `Proyecto System`, `Caseiterable System`, `Hashable System`, `Filesource System`, `Services System`?**
  _High betweenness centrality (0.210) - this node is a cross-community bridge._
- **Why does `ProjectMarkdownParser` connect `Markdown Parsing` to `Project Service`, `Parser Tests`, `Front Matter Tests`, `Project Discovery`, `Extensions System`, `Audioformat System`, `Asyncparsablecommand System`, `Equatable System`?**
  _High betweenness centrality (0.206) - this node is a cross-community bridge._
- **Why does `ProjectMarkdownParserTests` connect `Parser Tests` to `Markdown Parsing`, `Swiftproyectotests System`, `Swiftproyectotests System`?**
  _High betweenness centrality (0.161) - this node is a cross-community bridge._
- **Are the 27 inferred relationships involving `ProjectMarkdownParser` (e.g. with `.from()` and `.parseBatchConfig()`) actually correct?**
  _`ProjectMarkdownParser` has 27 INFERRED edges - model-reasoned connections that need verification._
- **Are the 21 inferred relationships involving `GitRepositoryFileSource` (e.g. with `.fileSource()` and `.testDiscoverAndRead_Integration()`) actually correct?**
  _`GitRepositoryFileSource` has 21 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Package`, `String`, `Version` to the rest of the system?**
  _208 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Project Service` be split into smaller, more focused modules?**
  _Cohesion score 0.07686274509803921 - nodes in this community are weakly interconnected._