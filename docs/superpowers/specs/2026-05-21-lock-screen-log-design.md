# Lock Screen Log Template Design

## Goal

Add an unlimited-cut video template that renders an iPhone lock-screen-style overlay on every selected media item.

## Behavior

- The template uses every selected photo, Live Photo, or video.
- The first cut lasts 1.5 seconds. Every following cut lasts 1.0 second.
- Each cut reads its source asset creation date and renders:
  - date at 0.1 seconds after the cut starts, formatted like `5월 13일 화요일`
  - time at 0.2 seconds after the cut starts, formatted like `18:03`
  - user-entered bottom text at 0.5 seconds after the cut starts
- The bottom text stays fixed across all cuts.
- The overlay includes lock-screen camera and flashlight controls under the bottom text.
- If an asset has no creation date, rendering falls back to the current date.

## Architecture

- Extend `SelectedMediaItem` to carry `creationDate`.
- Add a dedicated lock-screen overlay configuration to `VideoTemplate`.
- Reuse the existing render pipeline in `DefaultVideoGenerationService`, adding per-clip overlay layers based on cumulative clip start times.
- Reuse `TemplateCinematicTextCustomization.secondaryText` as the user-editable bottom text for this template.

## Testing

- Unit tests cover dynamic duration rules, catalog registration, date preservation while reindexing, and request propagation of the bottom text customization.
- Build/test verification should run through the existing Xcode test target.
