# Changelog

All notable changes to the Cortex project will be documented in this file.

## [2026-02-03]
### Added
- **Quick Capture Tags**: Added support for adding tags/subjects directly within the `QuickFactWidget`.
- **Conditional Source Options**: The quote and page number fields in the capture bar now only appear for relevant sources (like PDFs/Books).
- **Mini Cortex Improvements**: Fixed the "black screen" bug by initializing `window_manager` in `main.dart` and ensuring `window.show()` is called after window creation. Standardized initialization logic in `MiniModeScreen`.

## [2026-02-04]
### Added
- **Mini Cortex Saved Facts**: Mini mode now loads and displays recent facts for the active source, refreshing after saves.
- **Mini Cortex Debug Logs**: Added detailed logging across mini window ↔ main app communication and quick capture saves.
- **YouTube Auto-Titles**: Pasting a YouTube URL auto-fills the source name as "{video} - {channel}" using oEmbed.
- **Default Source Type**: When a Home filter is selected, new sources auto-select that type.

### Fixed
- **Mini Cortex Close Behavior**: Closing the mini window no longer terminates the main app.
- **Mini Cortex Snackbar Errors**: Prevented missing `ScaffoldMessenger` crashes in mini mode.
- **Widget Disposal Crash**: Fixed "deactivated widget ancestor" errors when leaving Source Detail.
- **macOS PDF Access**: Added sandbox entitlements and security-scoped bookmarks for persistent PDF access with file picker fallback.
- **Selected Filter Text**: Selected filter chip text is now readable (forced to black).

## [2026-02-02]
### Fixed
- **Build Fix**: Resolved a compilation error in `MiniModeScreen` by standardizing the `QuickFactWidget` `onSave` callback naming and signature.

## [2026-01-23]
### Added
- **New App Icon**: Implemented the "Neon Neural" design across macOS and iOS for a more modern, premium aesthetic.
- **Automatic Automation Setup**: The app now automatically checks for and installs the "Save to Cortex" macOS service on first launch.
- **Review Screen Filters**: Enhanced fact filtering with source-based filters, toggleable tags, and a "Clear All Filters" button.
- **Knowledge Graph Toggles**: Added a UI toggle to show/hide manually created links in the Knowledge Graph for a cleaner visualization.
- **Cluster Sources**: Added `isCluster` field to `Source` model for automatic capture routing based on URL prefix matching.
- **Fact URLs**: Individual captures now persist their origin URL even when grouped into a Source.

### Fixed
- **Path Detection**: Significantly improved project root detection in `AutomationService` to reliably find the setup script across various development environments.
- **Startup Cleanup**: Removed redundant persistence logic for pending captures that was causing potential state conflicts.

## [Planned]
### Added
- **PDF Reading Session**: Tie capture auto-routing to the Source Detail screen lifecycle. Improved session termination using `PopScope` to ensure sessions end reliably on exit.
- **Strict Captures**: Auto-save facts from PDF apps without dialog popups when a session is active.
- **Source-wide Tags**: Added `defaultTags` to `Source` model for automatic categorization during sessions.
- **Drag and Drop**: Handle PDF file drops on the Home screen for quick source navigation/creation.

### Fixed
- **URL Persistence**: Fixed issue where `isCluster` and Source `url` were lost during Firebase synchronization.
- **Dialog Visibility**: Fixed a race condition where the Capture Dialog wouldn't appear due to deep links arriving during Navigator transitions.
- **Redundancy**: Removed obsolete `EditSourceScreen` in favor of a unified `AddSourceScreen`.
- **Link Matching**: Improved `_findMatchingSource` with Longest Prefix Matching for Cluster Sources.
- **macOS Build**: Restored proper code signing to ensure Firebase Auth (Google Sign-In) works correctly. Note: Requires a valid developer profile in Xcode.

## [Initial Version]
- Initial release with capture, graph, and SRS features.
