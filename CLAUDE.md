# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

This is an Xcode project. Build and test from Xcode or via `xcodebuild`.

```bash
# Run unit tests
xcodebuild test -project auto-photos.xcodeproj -scheme auto-photos -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single named test (Swift Testing)
xcodebuild test -project auto-photos.xcodeproj -scheme auto-photos -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:auto-photosTests/auto_photosTests/homeExperienceUsesOnlyBuiltInTemplates
```

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). UI tests pass `UITEST_SCENARIO_*` launch arguments — `AppBootstrap.makeViewModel()` detects them and swaps in stub services.

## Architecture

### State machine

`GenerationState` (in `AutoPhotosModels.swift`) is the single driver of all screen transitions:

```
idle → selectionReview → generating(step:) → preview(GeneratedVideo)
                                           ↘ error(message:)
```

`ContentView` switches on `generationState` to show the right screen. All state mutations go through `AutoPhotosViewModel`.

### MVVM + protocol services

`AutoPhotosViewModel` owns all business logic and is the only `ObservableObject`. It holds protocol references injected at construction:

| Protocol | Default impl | UI-test stub |
|---|---|---|
| `PhotoLibraryService` | `DefaultPhotoLibraryService` | `StubPhotoLibraryService` |
| `VideoGenerationService` | `DefaultVideoGenerationService` | `StubVideoGenerationService` |
| `VideoSaveService` | `DefaultVideoSaveService` | `StubVideoSaveService` |
| `TemplateLibraryService` | `DefaultTemplateLibraryService` | `StubTemplateLibraryService` |
| `SubscriptionService` | `StoreKitSubscriptionService` | — |
| `RewardedAdService` | `AdMobRewardedAdService` | `NoOpRewardedAdService` |

`AppBootstrap.makeViewModel()` is the composition root. Stubs live at the bottom of `AutoPhotosViewModel.swift`.

### Template system

`VideoTemplate` (in `Templates/VideoTemplate.swift`) has two selection modes:

- **Fixed count** (`usesSelectionCount == false`): requires exactly `photoCount` items; `clipDurations` is a fixed array.
- **Dynamic count** (`usesSelectionCount == true`): accepts a range `[minimumPhotoCount, maximumPhotoCount]`; clip durations are generated from `leadingClipDurations` + `repeatingClipDuration`, or via a `DynamicClipPattern` (e.g. `.rhythmFlex918`).

`TemplateCatalog.templates` is the authoritative list of 5 built-in templates. Adding a new template means appending to that array and defining a `static let` extension on `VideoTemplate`.

Premium templates are identified by `isPremiumTemplate`. Download access is gated by `SubscriptionService.isSubscribed` or `RewardedDownloadAccessStore` (one rewarded-ad save per 24 h).

### Video generation

`DefaultVideoGenerationService` uses AVFoundation to compose a 1080×1920 vertical video at 30 fps. The pipeline has three reported steps: `.preparing` (load assets) → `.composing` (build AVMutableComposition + audio mix + text/overlay layers) → `.exporting` (AVAssetExportSession). Rendered videos are cached by `VideoRenderOptions` in the view model to avoid re-encoding when the user toggles music/text options.

### Localization

`L10n` is a plain `struct`, not a singleton. It detects Korean (`ko`/`ko-*`) vs English from `Locale.current`. All user-facing strings should go through `L10n` — either via the shared `l10n` instance in the view model and views, or by passing `L10n()` explicitly to methods that need it. Error messages in `AutoPhotosError.userMessage(using:)` follow the same pattern.

### Brand & theming

`LocketTheme` (in `Brand/`) provides all design tokens (colors, radii, fonts). `TemplateTheme` per-template color tokens are separate and used only during video rendering.

### Analytics

`AnalyticsClient` protocol with `AmplitudeAnalyticsClient` (prod) and `NoOpAnalyticsClient` (tests). All tracked events are static factory methods on `AnalyticsEvent`.
