# Lock Screen Log Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an unlimited-cut lock-screen video template with per-asset date/time overlays and user-entered bottom text.

**Architecture:** Store photo metadata on selected items, add a template-level lock-screen overlay configuration, and render per-cut Core Animation layers during export. Use existing customization UI/state instead of introducing a separate editing model.

**Tech Stack:** Swift, SwiftUI, Photos, AVFoundation/Core Animation, Swift Testing.

---

### Task 1: Failing Coverage

**Files:**
- Modify: `auto-photosTests/auto_photosTests.swift`

- [ ] Add tests for the new template duration pattern, catalog registration, `SelectedMediaItem.creationDate` preservation after reorder/removal, and propagation of bottom text customization in `VideoGenerationRequest`.
- [ ] Run `xcodebuild test -scheme auto-photos -destination 'platform=iOS Simulator,name=iPhone 16'` and verify the new tests fail before implementation.

### Task 2: Models And Catalog

**Files:**
- Modify: `auto-photos/AutoPhotosModels.swift`
- Modify: `auto-photos/Templates/VideoTemplate.swift`
- Modify: `auto-photos/Templates/TemplateCatalog.swift`

- [ ] Add `creationDate` to `SelectedMediaItem`.
- [ ] Add codable `TemplateLockScreenOverlay` settings to `VideoTemplate`.
- [ ] Add the new built-in template with unlimited selection, first cut 1.5 seconds, following cuts 1.0 second, and default bottom text.

### Task 3: Selection Metadata And UI Text

**Files:**
- Modify: `auto-photos/Services/DefaultPhotoLibraryService.swift`
- Modify: `auto-photos/AutoPhotosViewModel.swift`
- Modify: `auto-photos/ContentView.swift`

- [ ] Populate `creationDate` from `PHAsset.creationDate`.
- [ ] Preserve `creationDate` when reindexing selections.
- [ ] Show a bottom-text-focused customization card for the lock-screen template.

### Task 4: Renderer

**Files:**
- Modify: `auto-photos/Services/DefaultVideoGenerationService.swift`

- [ ] Include lock-screen overlays when creating the video composition.
- [ ] Add per-cut date/time/bottom-text layers at the requested offsets.
- [ ] Draw camera and flashlight controls with Core Animation/SF Symbols.

### Task 5: Verify

**Files:**
- No source changes expected.

- [ ] Run targeted tests.
- [ ] Run the broadest feasible build/test command and report the exact result.
