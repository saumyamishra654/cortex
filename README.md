# Cortex

A personal knowledge collection app with spaced repetition and knowledge graph features.

## Features

- Source Management (books, podcasts, articles, PDFs)
- Fact Capture with subject tags
- PDF Reader Sessions (Strict auto-routing for PDF Expert/Preview)
- Source-wide default tags
- Drag-and-drop file import
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
Cortex is designed for macOS with deep system integration:

1. **Automatic Setup**: On first launch, Cortex will attempt to install the "Save to Cortex" service automatically.
2. **Manual Installation**: If needed, you can re-run the setup from the Settings screen or via the terminal:
   ```bash
   chmod +x scripts/setup_cortex_service.sh
   ./scripts/setup_cortex_service.sh
   ```
3. **Help**: See [docs/macos_capture_shortcut.md](file:///Users/saumyamishra/Desktop/Projects/cortex/docs/macos_capture_shortcut.md) for manual configuration details.

### Advanced Features
- **Neon Neural Interface**: A premium, modern look with a custom-designed app icon.
- **Universal Capture**: Capture text from browsers (Chrome, Safari, Arc) with automatic URL preservation.
- **PDF Reader Sessions**: Active sessions automatically route captures from PDF Expert or Preview.
- **Drag-and-Drop**: Drop PDFs onto the Home screen to instant-open/create sources.

See [CHANGELOG.md](file:///Users/saumyamishra/Desktop/Projects/cortex/CHANGELOG.md) for recent updates.
