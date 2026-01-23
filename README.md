# Cortex

A personal knowledge collection app with spaced repetition and knowledge graph features.

## Features

- Source Management (books, podcasts, articles)
- Fact Capture with subject tags
- Spaced Repetition (SM-2 algorithm)
- Knowledge Graph visualization
- Smart Collections
- Dark/Light themes

## Live Demo

[https://saumyamishra654.github.io/cortex/](https://saumyamishra654.github.io/cortex/)

## Tech Stack

- Flutter
- Hive (local storage)
- Provider (state management)

## System-wide Capture (macOS)

Cortex supports capturing text from any application on macOS.

### Setup
For the best experience, we recommend installing the "Save to Cortex" macOS Service:

1. **Automated Setup**:
   ```bash
   chmod +x scripts/setup_cortex_service.sh
   ./scripts/setup_cortex_service.sh
   ```
2. **Manual Setup / Help**: See [docs/macos_capture_shortcut.md](file:///Users/saumyamishra/Desktop/Projects/cortex/docs/macos_capture_shortcut.md).

### Features
- Capture text from browsers (Chrome, Safari, Arc) with automatic URL context.
- Capture file paths from Finder or Preview.
- Spawns the capture dialog instantly without leaving your active app.

See [CHANGELOG.md](file:///Users/saumyamishra/Desktop/Projects/cortex/CHANGELOG.md) for recent updates.
