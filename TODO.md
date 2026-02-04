# TODO

## High Priority
- [x] Add Search functionality to `HomeScreen`.
- [ ] Implement AI-assisted tag suggestions based on fact content.
- [ ] Refine graph physics for larger datasets (performance optimization).
- [ ] Add a better view for the search page: filter by source type (Have buttons for pdf, conversation, course etc...)
- [x] Easier way to enter facts for a source: have fact entering space on the top, no separate screen for entering facts (Standardized `QuickFactWidget` for reuse).
- [ ] For PDFs, add a way to select a specific page, and add a way to annotate a line directly (add a line from the pdf, and then a thought about it)
- [ ] streaming mode from pdfs, do not snap back to the app
- [x] mini cortex thing that can hang around on the foreground of a pdf and have stuff get annotated there directly (Fixed black screen and added tag support).

## Features
- [x] Add PDF source support with text extraction (Integrated via Session Flow).
- [ ] Implement "Smart Merge" for duplicate sources.
- [ ] Mobile-specific UI tweaks for smaller screens.

## Technical Debt
- [ ] Add unit tests for `DeepLinkService` parsing logic.
- [ ] Refactor `DataProvider` sync logic to use a more robust strategy (tombstones).
- [ ] Optimize embedding generation to happen in batches.
