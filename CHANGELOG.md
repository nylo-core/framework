## [7.1.25] - 2026-07-06

### Fixed
* `make:api_service` — acronym-spelled names (e.g. `PaymentsAPIService`) no longer produce a doubled `ApiServiceApiService` class name; the suffix is now stripped case-insensitively and falls back to `api` for suffix-only input
* Generated API service now always imports `package:nylo_framework/nylo_framework.dart` (previously omitted when a custom `--url` was supplied, breaking the `NyApiService` reference)
* Generated `env.g.dart` now escapes single quotes and backslashes in keys and values, so secrets containing `'` or `\` can't break the generated Dart string literal

### Changed
* `make:api_service` info hint now points to `bootstrap/decoders.dart` (was `config/decoders.dart`)
* Generated `env.g.dart` adds explicit local variable type annotations and a `dart:typed_data` import (satisfies the `specify_nonobvious_local_variable_types` lint)
* Bump `nylo_support` dependency from `^7.27.2` to `^7.27.3`
* Bump `flutter_local_notifications` dependency from `^22.0.0` to `^22.0.1`
* Bump `dio` dependency from `^5.9.2` to `^5.10.0`

## [7.1.24] - 2026-06-08

### Changed
* Bump `nylo_support` dependency from `^7.27.1` to `^7.27.2`
* Bump `flutter_local_notifications` dependency from `^21.0.0` to `^22.0.0`
* Raise minimum environment constraints to Dart `^3.12.0` and Flutter `>=3.44.0`

## [7.1.23] - 2026-06-02

### Changed
* Bump `nylo_support` dependency from `^7.26.2` to `^7.27.1`
* Bump `patrol` dependency from `^4.6.0` to `^4.6.1`

## [7.1.22] - 2026-05-27

### Changed
* Improved `make:interceptor` Metro stub: added docstrings for `onRequest`, `onResponse`, and `onError`, and replaced `super.onRequest(...)` with `handler.next(options)` so the generated interceptor passes the request through explicitly

## [7.1.21] - 2026-05-25

### Changed
* Updated `make:state_managed_widget` Metro stub to use the new `NyStateManaged` API with `baseState`/`id` instead of `stateName`, simplifying the generated widget

## [7.1.20] - 2026-05-23

### Changed
* Bump `nylo_support` dependency from `^7.26.1` to `^7.26.2`
* Bump `error_stack` dependency from `^2.1.3` to `^2.1.4`

## [7.1.19] - 2026-05-23

### Changed
* Bump `nylo_support` dependency from `^7.26.0` to `^7.26.1`
* Bump `collection` dependency from `^1.18.0` to `^1.19.1`
* Bump `patrol` dependency from `^4.5.0` to `^4.6.0`

## [7.1.18] - 2026-05-21

### Added
* New `make:deep_link_provider` Metro command to scaffold a deep link provider pre-wired for Nylo's deep-link capture

### Changed
* Bump `nylo_support` dependency from `^7.24.2` to `^7.26.0`
* Raise minimum environment constraints to Dart `^3.10.7` and Flutter `>=3.38.4`
* Relax `collection` dependency constraint from `^1.19.1` to `^1.18.0`

## [7.1.17] - 2026-05-10

### Changed
* Bump `nylo_support` dependency from `^7.24.1` to `^7.24.2`
* Bump `error_stack` dependency from `^2.1.2` to `^2.1.3`

## [7.1.16] - 2026-05-10

### Changed
* Bump `nylo_support` dependency from `^7.24.0` to `^7.24.1`

## [7.1.15] - 2026-05-07

### Changed
* Bump `nylo_support` dependency from `^7.23.1` to `^7.24.0`

## [7.1.14] - 2026-05-01

### Changed
* Bump `nylo_support` dependency from `^7.23.0` to `^7.23.1`
* Bump `error_stack` dependency from `^2.1.1` to `^2.1.2`

## [7.1.13] - 2026-04-30

### Changed
* Bump `nylo_support` dependency from `^7.22.0` to `^7.23.0`
* Updated `make:state_managed_widget` stub to use the new `NyStateManaged` base widget, enabling multi-instance state isolation via `stateName`

## [7.1.12] - 2026-04-28

### Changed
* Bump `nylo_support` dependency from `^7.21.0` to `^7.22.0`

## [7.1.11] - 2026-04-28

### Changed
* Bump `nylo_support` dependency from `^7.20.2` to `^7.21.0`

## [7.1.10] - 2026-04-26

### Changed
* Bump `nylo_support` dependency from `^7.20.0` to `^7.20.2`
* Bump `error_stack` dependency from `^2.0.1` to `^2.1.1`

## [7.1.9] - 2026-04-20

### Changed
* Bump `nylo_support` dependency from `^7.19.0` to `^7.20.0`

## [7.1.8] - 2026-04-12

### Changed
* Bump `nylo_support` dependency from `^7.18.1` to `^7.19.0`

## [7.1.7] - 2026-04-11

### Changed
* Bump `nylo_support` dependency from `^7.16.0` to `^7.18.1`

## [7.1.6] - 2026-04-11

### Changed
* Remove `--force` flag from `make:key` command, now always overwrites existing APP_KEY
* Page with controller stub now sets `stateManaged` to `false` by default

## [7.1.5] - 2026-04-06

### Changed
* Remove `--force` flag from `make:env` command, now always overwrites existing `env.g.dart`

## [7.1.4] - 2026-04-03

### Changed
* Bump `nylo_support` dependency from `^7.14.0` to `^7.14.1`

## [7.1.3] - 2026-04-02

### Changed
* Bump `nylo_support` dependency from `^7.13.0` to `^7.14.0`

## [7.1.2] - 2026-03-31

### Changed
* Bump `nylo_support` dependency from `^7.12.0` to `^7.13.0`

## [7.1.1] - 2026-03-29

### Changed
* Page stub now sets `stateManaged` to `false` by default for newly scaffolded pages

## [7.1.0] - 2026-03-29

### Added
* Subdirectory support for all `make:*` Metro commands — users can now specify paths like `make:stateless_widget login/BrandPanel` to organize generated files into subdirectories
* Tests for subdirectory parsing, stub generation, and file path creation across all make commands

### Changed
* Bump `nylo_support` dependency from `^7.11.2` to `^7.12.0`
* Bump `patrol` dependency from `^4.3.0` to `^4.5.0`

## [7.0.15] - 2026-03-12

### Changed
* Bump `nylo_support` dependency from `^7.11.1` to `^7.11.2`

## [7.0.14] - 2026-03-12

### Changed
* Bump `nylo_support` dependency from `^7.10.0` to `^7.11.1`
* Bump `flutter_local_notifications` dependency from `^20.1.0` to `^21.0.0`

## [7.0.13] - 2026-03-09

### Changed
* Bump `nylo_support` dependency from `^7.9.1` to `^7.10.0`
* Bump `patrol` dependency from `^4.2.0` to `^4.3.0`

## [7.0.12] - 2026-03-06

### Changed
* Bump `nylo_support` dependency from `^7.9.0` to `^7.9.1`

## [7.0.11] - 2026-03-05

### Changed
* Bump `nylo_support` dependency from `^7.8.1` to `^7.9.0`
* Bump `patrol` dependency from `^4.1.1` to `^4.2.0`

## [7.0.10] - 2026-03-04

### Changed
* Bump `nylo_support` dependency from `^7.7.0` to `^7.8.1`
* Bump `skeletonizer` dependency from `^2.1.2` to `^2.1.3`
* Bump `flutter_local_notifications` dependency from `^20.0.0` to `^20.1.0`
* Bump `dio` dependency from `^5.9.0` to `^5.9.2`
* Bump `error_stack` dependency from `^2.0.0` to `^2.0.1`
* Bump `patrol` dependency from `^4.1.0` to `^4.1.1`

## [7.0.9] - 2026-03-01

### Changed
* Bump `nylo_support` dependency from `^7.6.0` to `^7.7.0`

## [7.0.8] - 2026-02-26

### Changed
* Bump `nylo_support` dependency from `^7.5.0` to `^7.6.0`

## [7.0.7] - 2026-02-23

### Changed
* Simplify API service stub constructor by removing `BuildContext` parameter -- generated API services now use a no-argument constructor with `super(decoders: modelDecoders)`
* Remove `package:flutter/material.dart` import from API service stub since `BuildContext` is no longer needed

### Fixed
* Fix malformed import statement in API service stub (duplicate `import '` prefix)

## [7.0.6] - 2026-02-21

### Changed
* Bump `nylo_support` dependency from `^7.4.0` to `^7.5.0`

## [7.0.5] - 2026-02-14

### Changed
* Bump `nylo_support` dependency from `^7.3.1` to `^7.4.0`

## [7.0.4] - 2026-02-14

### Changed
* Bump `nylo_support` dependency from `^7.3.0` to `^7.3.1`

## [7.0.3] - 2026-02-14

### Changed
* Bump `nylo_support` dependency from `^7.2.0` to `^7.3.0`
* Refine Metro CLI library directive to `library nylo_framework.metro` for clearer sub-library naming

### Added
* Dartdoc comment for `JsonDef.customObjectString` getter

## [7.0.2] - 2026-02-12

### Changed
* Add explicit return types to `NyCustomCommand` methods: `runProcess()` returns `Future<int>`, `addPackage()` and `addPackages()` return `Future<void>`, `info()`, `error()`, `success()`, and `warning()` return `void`
* Add explicit `List<String>` parameter type to all Metro `main()` entry points and explicit `dynamic` type to `NyJson.tryDecode()`, `Test.fromJson()`
* Update form stub init example to use `define()` and `FormCollection.from()` for field configuration
* Bump `nylo_support` dependency from `^7.1.0` to `^7.2.0`
* Add `lints: ^6.1.0` dev dependency and `analysis_options.yaml` with `package:lints/core.yaml`
* Improve `NyTheme.set()` doc comments for clarity

### Added
* Comprehensive dartdoc comments across all public APIs: `NyCustomCommand`, `ConsoleSpinner`, `ConsoleTable`, `ConsoleProgressBar`, `ApiService`, exception classes, `CommandBuilder`, `CommandResult`, `ClassType`, `DartCodeGenerator`, `JsonDef`, `ValueDef`, `ListInner`, and string extension helpers
* Library-level documentation for `nylo_framework` and Metro CLI

## [7.0.1] - 2026-02-10

### Fixed
* Fix event stub listener parameter name from `event` to `data` for clarity
* Add missing `{super.key}` to navigation hub stub constructor

## [7.0.0] - 2026-02-06

### Added
* **New modular command system** - All Metro CLI commands are now individual classes under `lib/metro/commands/make/`, each extending `NyCustomCommand` with a builder pattern. Commands are registered in `built_in_commands.dart` as a simple map lookup
* **`make:bottom_sheet_modal` command** - Generate bottom sheet modal widgets with auto-registration in `bottom_sheet_modals.dart`
* **`make:button` command** - Generate button widgets with auto-registration in the `Button` class
* **`make:env` command** - Generate an encrypted `env.g.dart` file from your `.env` file using XOR encryption with APP_KEY. Supports `--dart-define` mode for build-time key injection
* **`make:key` command** - Generate a secure 32-character APP_KEY for environment variable encryption
* **New `env_stub.dart`** - Stub for generating encrypted environment configuration class with automatic type parsing and caching
* **New `bottom_sheet_modal_stub.dart`** - Stub for generating bottom sheet modal widgets and their static registration methods
* **New `button_stub.dart`** - Stub for generating button widgets and their static registration methods
* **New `lib/metro/helpers/metro_helpers.dart`** - Extracted `NyJson` helper class and `createNyloModel` helper function
* **New `lib/app/` directory** - Added app directory structure with example model
* **Extensive new helper methods in `NyCustomCommand`**:
  * Output helpers: `line()`, `newLine()`, `comment()`, `alert()`
  * File system helpers: `fileExists()`, `directoryExists()`, `readFile()`, `readFileSync()`, `writeFile()`, `writeFileSync()`, `appendFile()`, `ensureDirectory()`, `deleteFile()`, `copyFile()`
  * Environment helpers: `env()`, `isWindows`, `isMacOS`, `isLinux`, `workingDirectory`
  * Input helpers: `ask()` (alias for prompt), `promptSecret()` for hidden input
  * Control flow: `abort()` to exit with error
  * Table display: `table()` with `ConsoleTable` class for formatted ASCII tables
  * Progress bar: `progressBar()` with `ConsoleProgressBar` class
  * String case conversion: `snakeCase()`, `camelCase()`, `pascalCase()`, `titleCase()`, `kebabCase()`, `constantCase()`
  * Flutter project path helpers: `modelsPath`, `controllersPath`, `widgetsPath`, `pagesPath`, `commandsPath`, `configPath`, `providersPath`, `eventsPath`, `networkingPath`, `themesPath`, `projectPath()`
  * File scaffolding: `scaffold()`, `scaffoldMany()` with `ScaffoldFile` class
  * JSON/YAML helpers: `readJson()`, `readJsonArray()`, `writeJson()`, `appendToJsonArray()`, `readYaml()`
  * Dart/Flutter command helpers: `dartFormat()`, `dartAnalyze()`, `flutterPubGet()`, `flutterClean()`, `flutterBuild()`, `flutterTest()`
  * Dart file manipulation: `addImport()`, `insertBeforeClosingBrace()`, `fileContains()`, `fileContainsPattern()`
  * Directory helpers: `listDirectory()`, `findFiles()`, `deleteDirectory()`, `copyDirectory()`
  * Validation: `isValidDartIdentifier()`, `requireArgument()`, `cleanClassName()`, `cleanFileName()`
  * Task runner: `runTasks()`, `runTasksWithSpinner()` with `CommandTask` class
* **New `ConsoleTable` class** - Renders formatted ASCII tables with box-drawing characters and bold headers
* **New `ConsoleProgressBar` class** - Displays progress bars with percentage tracking, tick/update/complete controls
* **New `SpinnerExtension` methods** - `withProgress()` and `withProgressSync()` for processing lists with progress bars
* **New `ScaffoldFile` class** - Data class for batch file scaffolding operations
* **New `CommandTask` class** - Data class for task runner operations with optional stop-on-error
* **`CommandResult.hasHelpFlag` and `hasForceFlag` convenience getters**
* **New `flutter_local_notifications` export** in `nylo_framework.dart`
* **New dependency: `patrol` (^4.1.0)** for testing
* **New dependency: `yaml` (^3.1.3)** for YAML file parsing
* **New dependency: `rename` (^3.1.0)** as dev dependency
* **New `executables` section in pubspec.yaml** - `metro: main` for direct CLI invocation
* **Comprehensive test suite** - New test directories: `test/commands/`, `test/console/`, `test/json_dart_generator/`, `test/metro/`, `test/stubs/` with tests for command builder, console components, spinner, JSON processing, scaffold files, menu display, stubs, and API exceptions
* **`NyTheme` class overhaul** - New static methods: `currentId()`, `current()`, `themeData()`, `isDark()`, `colors<T>()`, `setFollowSystem()`, `isFollowingSystem()`, `getById()`, `all()`, `lightThemes()`, `darkThemes()`, `getByType()`, `setPreferredDark()`, `setPreferredLight()`, `preferredDarkId()`, `preferredLightId()`, `clearSavedTheme()`
* **`NyTheme.set()` now supports `remember` parameter** - Sets preferred theme for system theme following

### Changed
* **Metro CLI entry point (`bin/main.dart`) rewritten** - Now uses direct command map lookup via `builtInCommands` instead of routing through the old `metro.dart` monolithic handler. Shows menu on no arguments, supports custom command discovery
* **Framework exports simplified (`lib/nylo_framework.dart`)** - Replaced 18+ individual `nylo_support` exports with single `export 'package:nylo_support/ny_core.dart'` re-export
* **`NyCustomCommand.run()` is now async** (`Future<void> run()`) and properly awaits `handle()`
* **`NyCustomCommand` exports updated** - Now exports from `package:nylo_support/metro/ny_metro.dart` and `/metro/helpers/metro_helpers.dart` instead of multiple individual support package paths
* **`CommandBuilder` constructor** - No longer auto-adds `--help` flag by default
* **`CommandResult` return types made nullable** - `getString()`, `getBool()`, `getInt()` now return nullable types with nullable defaults instead of non-nullable with required defaults
* **Provider stub updated** - `boot()` renamed to `setup()`, `afterBoot()` replaced with `boot()` (called after all providers are setup)
* **Route guard stub updated** - `onRequest(PageRequest)` replaced with `onBefore(RouteContext)` returning `Future<GuardResult>`, with new context helpers (`context.data`, `context.queryParameters`, `context.routeName`, `context.context`)
* **Form stub updated** - `NyFormData` renamed to `NyFormWidget`, constructor uses `super.key`, `super.submitButton`, `super.onSubmit`, `super.onFailure`. Fields use `FormCollection.fromArray()` for picker options, `validator` instead of `validate`, removed `style: "compact"`. Added static `NyFormActions` getter
* **API service stub updated** - Import path changed from `/config/decoders.dart` to `/bootstrap/decoders.dart`, added `interceptors` getter override
* **Config stub updated** - Now generates a `final class` with static members instead of loose comments, docs link updated to 7.x
* **Custom command stub updated** - Simplified usage docs (removed duplicate terminal/metro instructions)
* **Navigation hub stub rewritten** - Now accepts `layoutBuilder`, `imports`, and `navigationEntries` parameters. Layout uses `layout(BuildContext context)` method instead of property assignment. Added `initialIndex` override. Navigation pages use a synchronous map constructor `super(() => {...})` instead of async
* **Navigation hub creation (`make:navigation_hub`)** - Now interactive: prompts for layout type (navigation_tabs or journey_states) and child names. Generates hub and child widgets under organized folder structure (`navigation_hubs/<hub>/tabs/` or `navigation_hubs/<hub>/states/`)
* **Journey state stub improved** - New `isLastStep` parameter. Last step gets `onJourneyComplete` callback. Navigation buttons (Back/Continue) now built inline. Removed `onCannotContinue()` and `onAfterNext()` overrides. Updated to use `nextStep` instead of `onNextPressed`
* **Model stub formatting** - Removed extra blank lines for cleaner output
* **State managed widget stub updated** - Added static `action()` method for easier state action invocation. Updated example comments to use new `Follow.action()` pattern. Simplified `init` to synchronous
* **Stateful widget stub updated** - `widgetStatefulStub()` now accepts optional `content` parameter
* **`NyTheme.set()` is now async** and delegates to `NyThemeManager.instance.setTheme()` instead of `ThemeProvider`
* **JSON dart generator fixes** - `findCustomObject()` now returns nullable `ValueDef?` with proper null checks, `isStructSame` handles empty list comparison, `_summarizeData` list merging fixed with proper `nonNulls.toList()` chain, fromJson uses correct key reference
* **README.md** - All documentation links updated from `6.x` to `7.x`
* **LICENSE** - Copyright year updated to 2026
* **pubspec.yaml updates**:
  * Repository URL updated to `7.x` branch
  * `nylo_support` dependency changed to path reference (`path: ../support`)
  * `skeletonizer` updated to `^2.1.2`
  * `error_stack` updated to `^2.0.0`
  * Added `flutter_local_notifications: ^20.0.0`
  * Added `yaml: ^3.1.3`
  * Added `patrol: ^4.1.0`
  * Added `rename: ^3.1.0` (dev dependency)
  * Added `executables` section with `metro: main`
  * Added `uses-material-design: true`

### Removed
* **`lib/metro/metro.dart`** - Monolithic 1,400+ line command handler replaced by modular command classes
* **`lib/cli_dialog/` directory** - Entire CLI dialog library removed (7 files: `cli_dialog.dart`, `dialog.dart`, `keys.dart`, `list_chooser.dart`, `services.dart`, `stdin_service.dart`, `stdout_service.dart`, `xterm.dart`)
* **`lib/metro/stubs/theme_stub.dart`** - Theme generation stub removed
* **`lib/metro/stubs/theme_colors_stub.dart`** - Theme colors generation stub removed
* **`lib/metro/stubs/network_method_stub.dart`** - Network method stub removed
* **`lib/metro/stubs/postman_api_service_stub.dart`** - Postman API service stub removed
* **`make:theme` command** - Removed from Metro CLI menu
* **`NyCustomCommand.makeFile()` method** - Removed in favor of `scaffold()` and `writeFile()` helpers
* **`theme_provider` dependency** - Replaced by `NyThemeManager` from nylo_support
* **`flutter_secure_storage` dependency** - Removed from direct exports
* **`flutter_dotenv` dependency** - Removed (replaced by encrypted env system)
* **Individual nylo_support exports** - 18+ individual exports replaced by single `ny_core.dart` barrel export
* **`nyloVersion` updated** from `v6.9.2` to `v7.0.0`

## [6.8.15] - 2025-08-04

* Fix controller stub
* Update state managed stub
* pubspec.yaml updates

## [6.8.14] - 2025-07-18

* pubspec.yaml updates

## [6.8.13] - 2025-07-17

* pubspec.yaml updates

## [6.8.12] - 2025-07-14

* pubspec.yaml updates

## [6.8.11] - 2025-07-02

* pubspec.yaml updates

## [6.8.10] - 2025-06-24

* pubspec.yaml updates

## [6.8.9] - 2025-06-23

* pubspec.yaml updates

## [6.8.8] - 2025-06-20

* pubspec.yaml updates
 
## [6.8.7] - 2025-05-23

* pubspec.yaml updates

## [6.8.6] - 2025-05-08

* pubspec.yaml updates

## [6.8.5] - 2025-05-02

* Fix: postman imports
* pubspec.yaml updates

## [6.8.4] - 2025-04-30

* pubspec.yaml updates

## [6.8.3] - 2025-04-24

* pubspec.yaml updates

## [6.8.2] - 2025-04-19

* pubspec.yaml updates

## [6.8.1] - 2025-04-16

* Fix `runProcess` in ny_cli.dart
 
## [6.8.0] - 2025-04-16

* New stub for creating `JourneyState`s in your project
* Update `navigation_hub` stub
* Ability to create multiple `stateful_widget`s at once using Metro. E.g. `metro make:stateful_widget home,settings`
* Ability to create multiple `stateless_widget`s at once using Metro. E.g. `metro make:stateless_widget home,settings`
* pubspec.yaml updates

## [6.7.6] - 2025-04-11

* Fix methods: `addPackage` and `addPackages`

## [6.7.5] - 2025-04-11

* Small refactor to metro.dart

## [6.7.4] - 2025-04-10

* Fix commands not being run using `runProcess`

## [6.7.3] - 2025-04-09

* Update pubspec.yaml

## [6.7.2] - 2025-04-09

* Update command stub

## [6.7.1] - 2025-04-09

* Update `builder` in NyCustomCommand class

## [6.7.0] - 2025-04-08

* Added: `make:command` to metro cli so you can create custom commands in Nylo 🚀 
* Added: New stub for creating commands
* Update metro cli to support custom commands
* New ny_cli.dart file to handle custom commands
* Update pubspec.yaml

## [6.6.5] - 2025-04-01

* Update pubspec.yaml

## [6.6.4] - 2025-03-31

* Update pubspec.yaml

## [6.6.3] - 2025-03-27

* Update pubspec.yaml

## [6.6.2] - 2025-03-21

* Update pubspec.yaml

## [6.6.1] - 2025-02-28

* Update pubspec.yaml

## [6.6.0] - 2025-02-27

* Update Form stub to include `submitButton`
* Update pubspec.yaml

## [6.5.13] - 2025-02-23

* Update GitHub workflows
* Merge PR from [rytisder](https://github.com/rytisder) to fix page_w_controller_stub.dart
* Update pubspec.yaml

## [6.5.12] - 2025-02-10

* Update pubspec.yaml

## [6.5.11] - 2025-02-05

* Update pubspec.yaml

## [6.5.10] - 2025-02-04

* Update pubspec.yaml

## [6.5.9] - 2025-02-02

* Update pubspec.yaml

## [6.5.8] - 2025-01-29

* Update pubspec.yaml

## [6.5.7] - 2025-01-26

* Update pubspec.yaml
 
## [6.5.6] - 2025-01-16

* Update pubspec.yaml

## [6.5.5] - 2025-01-12

* Fix model stub
* Update pubspec.yaml
 
## [6.5.4] - 2025-01-06

* Update pubspec.yaml

## [6.5.3] - 2025-01-04

* Update route guard stub
* Update pubspec.yaml
 
## [6.5.2] - 2024-12-31

* Update copyright year 
* Update pubspec.yaml

## [6.5.1] - 2024-12-29

* Update pubspec.yaml

## [6.5.0] - 2024-12-29

* Update Form stub to include `init`
* Update pubspec.yaml
 
## [6.4.4] - 2024-12-22

* Update pubspec.yaml

## [6.4.3] - 2024-12-19

* Update pubspec.yaml

## [6.4.2] - 2024-12-18

* Update pubspec.yaml

## [6.4.1] - 2024-12-18

* Update pubspec.yaml

## [6.4.0] - 2024-12-16

* Added: 
* export 'package:nylo_support/widgets/styles/bottom_modal_sheet_style.dart'; 
* export 'package:nylo_support/helpers/ny_color.dart'; 
* export 'package:nylo_support/helpers/ny_text_style.dart';

## [6.3.2] - 2024-12-13

* Update pubspec.yaml

## [6.3.1] - 2024-12-12

* Update pubspec.lock

## [6.3.0] - 2024-12-12

* Update pubspec.yaml

## [6.2.10] - 2024-12-08

* Update pubspec.yaml

## [6.2.9] - 2024-12-06

* Update pubspec.yaml

## [6.2.8] - 2024-12-01

* Update NavigationHub stub

## [6.2.7] - 2024-11-29

* Update pubspec.yaml

## [6.2.6] - 2024-11-29

* Update widget stubs to use `view`

## [6.2.5] - 2024-11-27

* Update pubspec.yaml

## [6.2.4] - 2024-11-25

* Update pubspec.yaml

## [6.2.3] - 2024-11-23

* Update stub constructors to include `{super.key}`
* Update pubspec.yaml

## [6.2.2] - 2024-11-15

* Update pubspec.yaml

## [6.2.1] - 2024-11-13

* Update pubspec.yaml

## [6.2.0] - 2024-11-10

* Remove page_bottom_nav_stub
* Update pubspec.yaml

## [6.1.2] - 2024-11-08

* Update pubspec.yaml

## [6.1.1] - 2024-11-08

* Update page_w_controller_stub
* Contribution from [jitendravn](https://github.com/jitendravn) PR [#40](https://github.com/nylo-core/framework/pull/40)
 
## [6.1.0] - 2024-11-04

* Update pubspec.yaml

## [6.0.0] - 2024-11-02

* New version of Nylo - read more about the changes [here](https://nylo.dev/)

## [5.32.6] - 2024-07-18

* Small refactor to cli_dialog to pass static analysis
* Update pubspec.yaml

## [5.32.5] - 2024-07-09

* Update import paths in Metro

## [5.32.4] - 2024-07-09

* Update pubspec.yaml

## [5.32.3] - 2024-07-09

* Update pubspec.yaml

## [5.32.2] - 2024-07-08

* Refactor Form stub
* Update pubspec.yaml

## [5.32.1] - 2024-07-06

* Update pubspec.yaml

## [5.32.0] - 2024-07-06

* Update the Form stub
* Add new dependency `date_field`
* update README
* Update pubspec.yaml

## [5.31.2] - 2024-07-05

* Update pubspec.yaml

## [5.31.1] - 2024-07-03

* Update pubspec.yaml

## [5.31.0] - 2024-07-02

* Ability to create Forms using Metro. E.g. `metro make:form register`
* New stub for creating Forms
* Small refactor to model stub
* Refactor `slate` command to `metro slate:publish`
* New `metro slate:install` command to install the slate package and publish all the files

## [5.30.0] - 2024-06-16

* Update stubs
* Update pubspec.yaml

## [5.29.6] - 2024-06-14

* Update pubspec.yaml

## [5.29.5] - 2024-06-14

* Update pubspec.yaml

## [5.29.4] - 2024-06-14

* Update pubspec.yaml

## [5.29.3] - 2024-06-13

* Update pubspec.yaml

## [5.29.2] - 2024-06-13

* Fix `apiServiceStub` to use `destroy` instead of `delete`

## [5.29.1] - 2024-06-12

* Update pubspec.yaml

## [5.29.0] - 2024-06-11

* Fix `Metro` to not add duplicate suffixes to some files
* Update pubspec.yaml

## [5.28.2] - 2024-06-06

* Update pubspec.yaml

## [5.28.1] - 2024-06-05

* Dart format

## [5.28.0] - 2024-06-05

* Remove the ability to use a "postman.json" file in the `_makeApiService` command
* Update pubspec.yaml

## [5.27.6] - 2024-05-22

* Update pubspec.yaml

## [5.27.5] - 2024-05-17

* Update pubspec.yaml

## [5.27.4] - 2024-05-14

* Update pubspec.yaml
* Add `dart_console`

## [5.27.3] - 2024-05-12

* Downgrade `flutter_secure_storage` to ^9.0.0

## [5.27.2] - 2024-05-11

* Update pubspec.yaml

## [5.27.1] - 2024-05-04

* Update pubspec.yaml

## [5.27.0] - 2024-05-01

* Add `error_stack` to framework

## [5.26.2] - 2024-04-29

* Fix `interceptor` stub

## [5.26.1] - 2024-04-28

* Update pubspec.yaml

## [5.26.0] - 2024-04-25

* Ability create multiple pages at once using Metro. E.g. `metro make:page home,dashboard,settings` // this will create 3 pages home_page, dashboard_page and settings_page
* Update pubspec.yaml

## [5.25.6] - 2024-04-25

* Update pubspec.yaml

## [5.25.5] - 2024-04-20

* Update pubspec.yaml

## [5.25.4] - 2024-04-20

* Update pubspec.yaml

## [5.25.3] - 2024-04-18

* Update metro make:model --json command to check if cli is running on Windows or MacOS 

## [5.25.2] - 2024-04-17

* Update pubspec.yaml

## [5.25.1] - 2024-04-08

* Update pubspec.yaml

## [5.24.6] - 2024-04-01

* Update pubspec.yaml

## [5.24.5] - 2024-03-31

* Update pubspec.yaml

## [5.24.4] - 2024-03-30

* Update pubspec.yaml

## [5.24.3] - 2024-03-28

* Update pubspec.yaml

## [5.24.2] - 2024-03-26

* Update pubspec.yaml

## [5.24.1] - 2024-03-25

* Update pubspec.yaml

## [5.24.0] - 2024-03-22

* Update stubs

## [5.23.0] - 2024-03-21

* Update stubs
* Update pubspec.yaml

## [5.22.2] - 2024-03-18

* Update pubspec.yaml

## [5.22.1] - 2024-03-18

* Update pubspec.yaml

## [5.22.0] - 2024-03-17

* Update config stub
* Update pubspec.yaml

## [5.21.10] - 2024-03-10

* Update pubspec.yaml

## [5.21.9] - 2024-03-07

* Update pubspec.yaml

## [5.21.8] - 2024-03-05

* Update pubspec.yaml

## [5.21.7] - 2024-03-04

* Add `skeletonizer` package
* Update pubspec.yaml

## [5.21.6] - 2024-02-28

* Update pubspec.yaml

## [5.21.5] - 2024-02-28

* Update pubspec.yaml

## [5.21.4] - 2024-02-26

* Update pubspec.yaml

## [5.21.3] - 2024-02-24

* Update pubspec.yaml

## [5.21.2] - 2024-02-16

* Update pubspec.yaml

## [5.21.1] - 2024-02-14

* Update pubspec.yaml

## [5.21.0] - 2024-02-12

* Tweak stubs
* Update pubspec.yaml

## [5.20.18] - 2024-02-08

* Update pubspec.yaml

## [5.20.17] - 2024-02-07

* Update pubspec.yaml

## [5.20.16] - 2024-02-07

* Update pubspec.yaml

## [5.20.15] - 2024-02-04

* Update pubspec.yaml

## [5.20.14] - 2024-02-04

* export `ny_language_switcher` to `nylo_framework.dart`
* Update pubspec.yaml

## [5.20.13] - 2024-02-02

* Update pubspec.yaml

## [5.20.12] - 2024-02-02

* Update pubspec.yaml

## [5.20.11] - 2024-02-01

* Update page stub docs

## [5.20.10] - 2024-02-01

* Update pubspec.yaml

## [5.20.9] - 2024-01-29

* Update pubspec.yaml

## [5.20.8] - 2024-01-28

* Remove `await Future.delayed(Duration(seconds: 2));` from stub
* Update config stub
* Update pubspec.yaml

## [5.20.7] - 2024-01-26

* Fix postman not automatically adding the `ApiService` into the `decoders.dart` file 
* Update pubspec.yaml

## [5.20.6] - 2024-01-24

* Add `override` to model stub

## [5.20.5] - 2024-01-23

* Update pubspec.yaml

## [5.20.4] - 2024-01-23

* Update pubspec.yaml

## [5.20.3] - 2024-01-22

* Update pubspec.yaml

## [5.20.2] - 2024-01-21

* Update pubspec.yaml

## [5.20.1] - 2024-01-18

* Update README.md

## [5.20.0] - 2024-01-18

* New `--bottom-nav` flag to create bottom nav pages. E.g. `metro make:page dashboard_nav --bottom-nav`
* Add new stub for creating pages that use bottom navigation tabs
* Update pubspec.yaml

## [5.19.0] - 2024-01-15

* Update page and controller stub to use `view` instead of `build`
* Update the page and controller stub to include controller getter
* Update pubspec.yaml

## [5.18.9] - 2024-01-13

* Update pubspec.yaml

## [5.18.8] - 2024-01-13

* Update pubspec.yaml

## [5.18.7] - 2024-01-11

* Improve `metro make:api_service` when using Postman flag

## [5.18.6] - 2024-01-11

* Improve `metro make:api_service` when using Postman flag

## [5.18.5] - 2024-01-10

* Fix `metro make:api_service` error when using Postman flag

## [5.18.4] - 2024-01-06

* Update pubspec.yaml

## [5.18.3] - 2024-01-03

* Update pubspec.yaml

## [5.18.2] - 2024-01-03

* Update stateful stub
* Update pubspec.yaml

## [5.18.1] - 2024-01-02

* Update pubspec.yaml

## [5.18.0] - 2024-01-01

* Update pubspec.yaml

## [5.17.0] - 2024-01-01

* Metro cli improvements
  * Ability to create pages in a subfolder. E.g. `metro make:page auth/login`
  * Ability to create models in a subfolder. E.g. `metro make:model auth/user`
  * Ability to create controllers in a subfolder. E.g. `metro make:controller auth/login`
  * Update `--postman` flag for API Services. Now you can run `metro make:api_service example_api_service --postman` and it will help you create an API Service from a Postman collection.
* Update stubs
* Add `cli_dialog` as a dependency
* Update pubspec.yaml

## [5.16.0] - 2023-12-25

* Update pubspec.yaml

## [5.15.0] - 2023-12-09

* Export new `ny_route_history_observer.dart` file
* Update pubspec.yaml

## [5.14.0] - 2023-12-03

* Update pubspec.yaml

## [5.13.0] - 2023-12-02

* Add new `--json` flag to the "make:model" command to create a model from a json string. E.g. `metro make:model user --json '{"name": "John Doe", "age": 30}'`

## [5.12.0] - 2023-12-02

* Update pubspec.yaml

## [5.11.1] - 2023-12-01

* Update pubspec.yaml

## [5.11.0] - 2023-11-25

* Update pubspec.yaml

## [5.10.0] - 2023-11-23

* Ability to set routes as the initialPage using **--initial** E.g. `metro make:page dashboard --initial`
* Ability to set routes as the authPage using **--auth** E.g. `metro make:page dashboard --auth`
* Update pubspec.yaml

## [5.9.0] - 2023-11-22

* New ability to create dio Interceptors using Metro. E.g. `metro make:interceptor auth_token`
* Update stubs for creating pages and api services
* Small refactor to Metro class
* Remove ny_base_networking.dart
* Update pubspec.yaml

## [5.8.0] - 2023-11-04

* Fix `make:api_service` when using Postman flag
* New `publish:slate` command added to Metro
* Added more docs to Metro methods

## [5.7.1] - 2023-10-27

* Update page stub to include an example on how to set the state. 

## [5.7.0] - 2023-10-22

* Ability to auto add themes to the Nylo config using e.g. `metro make:theme bright_theme`
* Update default theme stub to use `useMaterial3`
* Update pubspec.yaml

## [5.6.0] - 2023-10-19

* Add docblock to more APIs
* Update pubspec.yaml

## [5.5.0] - 2023-10-17

* Update page stub to use `NyPage`
* Fix metro make:api_service Postman error when URL is null
* Update pubspec.yaml

## [5.4.1] - 2023-10-08

* Update pubspec.yaml

## [5.4.0] - 2023-10-01

* Ability to create config files via Metro
* Update pubspec.yaml

## [5.3.7] - 2023-09-22

* Update pubspec.yaml

## [5.3.6] - 2023-09-14

* Update pubspec.yaml

## [5.3.5] - 2023-08-31

* Update pubspec.yaml

## [5.3.4] - 2023-08-31

* Update pubspec.yaml

## [5.3.3] - 2023-08-31

* Update pubspec.yaml

## [5.3.2] - 2023-08-28

* Add docblock to setPagination method and fix the queryParameters not being reset when using the `api` helper

## [5.3.1] - 2023-08-26

* Update pubspec.yaml

## [5.3.0] - 2023-08-25

* Update stateful_stub to remove `stateInit`
* Add `setPagination` to NyBaseNetworking
* Update pubspec.yaml

## [5.2.1] - 2023-08-21

* Update pubspec.yaml

## [5.2.0] - 2023-08-21

* Add `useUndefinedResponse` to `network` helper. This will allow you to catch the response when your decoder.dart file fails to return the correct type. To listen to undefinedResponse's, call `onUndefinedResponse(dynamic data, Response response, BuildContext? context)` in your ApiService.
* Update stateful_stub to include `stateInit` and `stateUpdated`
* Small refactor to page_stub 
* Fix Metro error -  The class 'FileSystemEvent' can't be extended, implemented
* Add json_dart_generator into the library

## [5.1.2] - 2023-07-13

* Pubspec.yaml dependency updates.

## [5.1.1] - 2023-07-03

* Pubspec.yaml dependency updates.

## [5.1.0] - 2023-06-17

* Breaking change to validation.
* If you are using Nylo 5.x, do the following:
  * Go to **config/validation_rules.dart**.
  * Update 'final Map<Type, dynamic> validationRules = {'
  * to this 'final Map<String, dynamic> validationRules = {'
  * Custom validation rules must now the follow the following format:
    * "simple_password": (attribute) => SimplePassword(attribute), // example
* Pubspec.yaml dependency updates.

## [5.0.6] - 2023-06-14

* Update Nylo framework version.

## [5.0.5] - 2023-06-14

* Update GitHub actions.
* Refactor metro class.
* Pubspec.yaml dependency updates.

## [5.0.4] - 2023-06-08

* Change nylo_framework version.

## [5.0.3] - 2023-06-08

* Change `DioError` to `DioException` as per dio upgrade notes.
* Refactor metro to use `runCommand` from MetroService.
* Pubspec.yaml dependency updates.

## [5.0.2] - 2023-05-28

* Pubspec.yaml dependency updates.

## [5.0.1] - 2023-05-24

* Pubspec.yaml dependency updates.

## [5.0.0] - 2023-05-16

* `NyBaseApiService` has a new method `getContext` to get the BuildContext.
* Remove 'Storable' from the Model stub.
* Page stubs now include a `path` variable to make routing easier.
* New command to create Route Guards.
* Pubspec.yaml dependency updates.
* Readme update.

## [4.2.0] - 2023-05-16

* Flutter v3.10.0 fixes:
    * Update: theme_provider package

## [4.1.5] - 2023-03-07

* Fix metro make:model if modelDecoders doesn't exist.

## [4.1.4] - 2023-03-03

* Pubspec.yaml dependency updates.

* ## [4.1.3] - 2023-02-22

* Pubspec.yaml dependency updates.

## [4.1.2] - 2023-02-14

* Add logo to package
* Pubspec.yaml dependency updates.

## [4.1.0] - 2023-01-30

* Update stubs.
* Now you can pass a baseUrl to the `network` or `nyApi` method.
* Small refactor to the Metro class.
* Fix importPaths when using `addToRouter`.
* Pubspec.yaml dependency updates.

## [4.0.0] - 2023-01-01

* Metro will automatically add Routes to the router.dart file
* Metro will automatically add Events to the config/events.dart file
* Metro will automatically add ApiServices and Models to the config/decoders.dart file
* Metro will automatically add Providers to the config/providers.dart file
* Create Api Services from Postman collections using Metro, read more [here](https://nylo.dev/docs/5.x/metro#make-api-service-using-postman)
* `NyBaseApiService` class has new parameters to add a `bearerToken` or `headers` on each request
* Update stubs
* Copyright year updated
* Pubspec.yaml dependency updates

## [3.4.0] - 2022-09-19

* Add page_transition to dependencies
* Pubspec.yaml dependency updates

## [3.3.0] - 2022-08-27

* Update theme stubs
* Pubspec.yaml dependency updates

## [3.2.0] - 2022-07-27

* Update page stub to include default base Controller on creation
* Refactor stubs using 'package:flutter_app' to use project path
* Pubspec.yaml dependency updates

## [3.1.4] - 2022-06-28

* Pubspec.yaml dependency updates

## [3.1.3] - 2022-05-19

* Add @override to event stubs
* Pubspec.yaml dependency updates

## [3.1.2] - 2022-05-04

* Add version to nylo_framework

## [3.1.1] - 2022-05-04

* Remove import from ny_base_networking.dart
* Flutter format

## [3.1.0] - 2022-05-04

* Add new `NyBaseApiService` class to the networking folder
* Add dio as a dependency
* Pubspec.yaml dependency updates

## [3.0.0] - 2022-04-29

* New command to create: Events, Providers and API Services
* Remove command: project:init
* Docs link updated in Model stub
* Update README info
* Remove nylo_support ref from stubs
* Pubspec.yaml dependency updates

## [2.2.0] - 2022-03-29

* Remove appended 'Widget' from Metro:make command for stateless and stateful widgets
* Docs link updated in Model stub
* Pubspec.yaml dependency updates

## [2.1.4] - 2022-01-02

* Merge PR #27 - Example moved to null safety
* Remove build appicons command from Metro cli

## [2.1.3] - 2021-12-17

* Small refactor to Metro Cli
* Pubspec.yaml dependency updates

## [2.1.2] - 2021-12-12

* Update Controller stub
* Pubspec.yaml dependency updates

## [2.1.1] - 2021-12-10

* Upgrade to Dart 2.15
* Add toast notifications
* Pubspec.yaml dependency updates

## [2.1.0] - 2021-12-08

* Update Nylo version
* Ability to create themes and theme colors from Metro Cli
* Pubspec.yaml dependency updates

## [2.0.4] - 2021-09-21

* Update Nylo version

## [2.0.3] - 2021-09-21

* Pubspec.yaml dependency updates

## [2.0.2] - 2021-09-18

* Upgrade Dart (v2.14.0)
* Pubspec.yaml dependency updates

## [2.0.1] - 2021-09-11

* Remove NyBaseColors class

## [2.0.0] - 2021-09-10

* Refactor nylo_framework.dart
* Metro cli stability improvements
* New NyTheme class for setting the Flutter theme
* Null safety stubs
* Pubspec.yaml dependency updates

## [1.1.0] - 2021-07-13

* Null safety stubs

## [1.0.1] - 2021-07-07

* README changes

## [1.0.0] - 2021-07-07

* New method to create pages in router 'router.page(NyStatefulWidget widget)'
* Pubspec.yaml dependency updates

## [0.8.5] - 2021-04-30

* Use pascal format for metro cli
* Fix metro make:page command

## [0.8.4] - 2021-04-29

* Fix stub using NyStatefulWidget

## [0.8.3] - 2021-04-28

* Fix stub using NyStatefulWidget

## [0.8.2] - 2021-04-10

* Remove operand check

## [0.8.1] - 2021-04-10

* Update adaptive_theme dependency

## [0.8.0] - 2021-04-10

* Null safety support
* Rename StatefulPageWidget to NyStatefulWidget
* Pubspec.yaml dependency updates

## [0.7.0+1] - 2021-03-16

* Changes as per dart analysis log

## [0.7.0] - 2021-03-16

* Router bug fix
* Small tweaks

## [0.6.2] - 2021-03-07

* Flutter 2.0.0+ support
* Bug fixes

## [0.6.1] - 2021-02-18

* Bug fixes

## [0.6.0] - 2021-02-18

* Ability to create plugins for Nylo
* Refactored NyRouter class
* Add page transitions
* `StatefulPageWidget` class now has `data()` method
* Controller and model stub update
* new `construct(context)` method for controllers
* Version bump

## [0.5.2] - 2021-01-31

* Fix `onPop` called on null
* Pass new "result" into `pop` method

## [0.5.1] - 2021-01-30

* `flutter format`

## [0.5.0] - 2021-01-30

* Metro new commands: create stateless widgets, stateful widgets and storable models
* "common" folder renamed to "resources"
* Router new `route` method to create routes
* Controller refactored to remove .of(BuildContext context)
* New Storable method `save('key')` to store to secure storage
* onPop parameter added to `routeTo` method
* Small improvements and tweaks

## [0.4.0] - 2020-12-21

* New default state widget NyState
* Updates to Metro stubs
* APIRender Widget parameter refactor
* Helper class small refactor
* Dart code formatting

## [0.3.2] - 2020-09-23

* ApiRender widget updated with new required parameters and change in functionality.

## [0.3.1] - 2020-09-19

* Small fix to Metro cli tool
* Update to readme

## [0.3.0] - 2020-09-18

* Bug fix for controller when fetching request data
* Tweak to routes and transitions
* Improvements to Metro Cli

## [0.2.0] - 2020-09-15

* Controllers can now return arguments from routes
* Dispatch jobs with the new BusQueue
* Updated router class
* ApiRender widget for rending Widgets from api futures
* Removal of unused methods, code clean up, example added
* New method for storing objects and lists to shared preferences
* New methods to check app connectivity in networking
* Metro improvements and bug fixes
* Bug fixes to project

## [0.1.0] - 2020-08-23

* Initial release.
