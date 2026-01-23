# Changelog

All notable changes to the Cortex project will be documented in this file.

## [2026-01-23]
### Added
- **Cluster Sources**: Added `isCluster` field to `Source` model. Sources marked as clusters can now automatically claim captures based on URL prefix matching.
- **Fact URLs**: Added `url` field to `Fact` model. Individual captures now persist their specific origin URL even when grouped into a broader Source.
- **Unified Source Editing**: Integrated source editing logic into `AddSourceScreen` and added an "Edit Source" option to the `HomeScreen` long-press menu and `SourceDetailScreen`.
- **Instrumentation**: Added debug logging to `CaptureDialog` and `main.dart` for tracing deep link handling.

### Fixed
- **URL Persistence**: Fixed issue where `isCluster` and Source `url` were lost during Firebase synchronization.
- **Dialog Visibility**: Fixed a race condition where the Capture Dialog wouldn't appear due to deep links arriving during Navigator transitions.
- **Redundancy**: Removed obsolete `EditSourceScreen` in favor of a unified `AddSourceScreen`.
- **Link Matching**: Improved `_findMatchingSource` with Longest Prefix Matching for Cluster Sources.

## [Initial Version]
- Initial release with capture, graph, and SRS features.
