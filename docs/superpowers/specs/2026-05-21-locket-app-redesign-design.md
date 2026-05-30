# Locket App Redesign Design

## Goal

Redesign the app around the Figma `app-design` reference and rename the user-facing product from `auto-photos` to `Locket`.

The redesign should make the app feel like a polished iOS memory-video tool: soft off-white surfaces, media-led template cards, clear fixed actions, and a simple flow from template selection to media ordering to export.

## Scope

- Keep the existing four built-in templates visible:
  - `맛집추천템플릿`
  - `Lock Screen Log`
  - `Life Fraems`
  - `All Photos Flow`
- Hide the custom template create, edit, and delete entry points from the main experience.
- Preserve the existing video generation pipeline, template ids, audio configuration, media picker behavior, drag reorder behavior, save behavior, and share behavior.
- Treat BGM as part of each video template. Do not add a premium BGM feature, advanced BGM catalog, or user-facing BGM selection flow in this redesign.
- Redesign the visible app screens and split the current large SwiftUI view into screen-level and component-level files.
- Add Korean and English UI text support. If the device language is Korean, show Korean. For all other languages, show English.
- Set the user-facing app display name and visible brand text to `Locket`.
- Improve the logo presentation so the cherry mark is centered inside a small circular brand/profile mark.

## Out Of Scope

- Renaming the four templates. The current names stay for now because they will be revisited later.
- Rewriting the video rendering engine.
- Renaming the Xcode project, target, bundle identifier, or test target unless needed for the user-facing display name.
- Reintroducing the custom template editor in the new design.
- Premium or advanced BGM features. Template BGM is always bundled with the selected video template.

## Design Direction

Use the Figma reference as the primary visual source:

- Background: warm off-white `#FFF8F7`.
- Accent: vivid pink `#FF7597`.
- Primary text: deep ink `#23191A`.
- Secondary text: muted cocoa `#534344`.
- Inputs and soft controls: pale pink `#FFF0F1`.
- Borders: soft rose `#F4E4E6` and `#DDBFC3`.
- Cards: white or image-backed surfaces with 8-16 pt corner radii depending on scale.
- Buttons: compact, clear iOS-style controls. Primary actions use the pink accent; secondary actions use white surfaces with rose borders.

The app should avoid the current heavy atmospheric/cherry-studio treatment. The new look should be lighter, cleaner, and closer to a native mobile product.

## Architecture

Split the current `ContentView` UI into smaller units:

- `LocketAppView`
  - Owns top-level routing between app states.
  - Connects to `AutoPhotosViewModel`.
  - Presents alerts, media picker, share sheet, and any global overlays.
- `TemplateGalleryScreen`
  - Replaces the current home state.
  - Shows the Locket top bar, headline, two-column template card grid, and fixed bottom action.
- `MediaSequenceScreen`
  - Replaces the current selection review state.
  - Shows title/text customization fields when supported, selected media rows, reorder affordances, validation text, reselect action, and generate CTA.
- `VideoPreviewScreen`
  - Replaces the current preview state.
  - Shows the 9:16 video preview, Music/Text toggles, save button, share button, retry action, and status messaging.
- `GenerationOverlay`
  - Presents the generation progress in the Locket style.
- `ErrorScreen`
  - Presents errors with recovery and reset actions.

Create reusable design components:

- `LocketTopBar`
- `LocketLogoView`
- `LocketTemplateCard`
- `LocketPrimaryButtonStyle`
- `LocketSecondaryButtonStyle`
- `LocketInputField`
- `LocketSequenceRow`
- `LocketToggleCard`
- `LocketBottomActionBar`

The ViewModel should remain the source of truth for app state. Screen components should receive view data and callbacks rather than owning generation logic.

## Screen Design

### Template Gallery

The gallery follows the Figma `main` frame:

- Top bar:
  - Left: centered cherry logo mark plus `Locket`.
  - Right: settings-style icon button matching the Figma frame. It opens no new screen in this pass.
- Headline:
  - Korean: `오늘을 어떤 무드로 기억할까요?`
  - English: `How do you want to remember today?`
  - Accent the key word visually where practical.
- Subtitle:
  - Korean: `원하는 스타일을 골라 기억을 영상으로 남겨보세요.`
  - English: `Choose a style and turn your memories into a video.`
- Template cards:
  - Two-column grid.
  - Image or gradient-backed 3:4 cards.
  - Template name and short description over a bottom gradient.
  - Selected card gets a subtle accent border or glow.
- Bottom CTA:
  - Fixed to the bottom safe area.
  - Disabled until a template is selected or picker can open.
  - Korean: `미디어 선택하기`
  - English: `Choose Media`

### Media Sequence

The sequence screen follows the Figma `array` frame:

- Top bar:
  - Left close/back action.
  - Center `Locket`.
  - Right settings icon matching the Figma frame. It opens no new screen in this pass.
- Header inputs:
  - Show text customization fields only for templates that support user text.
  - For Lock Screen Log, the editable field maps to the fixed bottom caption.
  - For cinematic templates, title and short sentence map to primary and secondary text.
  - Use pale pink input surfaces and small uppercase labels.
- Sequence list:
  - Replace the current 3-column thumbnail grid with vertical rows.
  - Each row shows index, thumbnail, media type, optional duration, and drag handle.
  - Keep long-press drag reorder and delete behavior.
- Actions:
  - A dashed reselect row or secondary button for selecting media again.
  - A primary bottom CTA for video generation.
  - Validation text appears above the CTA when generation is blocked.

### Video Preview

The preview screen follows the Figma `video download` frame:

- Top bar:
  - Close/back action, centered `Locket`, settings icon.
- Preview:
  - Large rounded 9:16 video preview with soft shadow.
  - Preserve existing looping video playback.
- Controls:
  - Music toggle and Text toggle in a pale pink control container.
  - The Music toggle only enables or disables the selected template's bundled BGM. It does not open a BGM picker or premium BGM catalog.
  - Disable unavailable toggles but keep the state visually clear.
- Actions:
  - Primary pink save button.
  - Secondary white share button.
  - Retry/reorder action as secondary text or button below the main actions.
- Status and notes:
  - Use compact inline text in the control area.

### Generation and Error

The generation state should feel like part of the same app, not an old glass panel:

- Use the Locket background and card surface.
- Show a spinner, current generation step, helper text, and cancel button.
- Error screen uses a white card, concise message, primary recovery action, and secondary reset action.

## Localization

Add a small localization layer for Korean and English UI text:

- Detect `Locale.current.language.languageCode`.
- Use Korean for `ko`.
- Use English for every other language.

The initial implementation can be code-based with a typed `L10n` namespace so the refactor does not require a full string catalog migration. The structure should still make future string catalog migration straightforward.

Template names remain sourced from template definitions for now. Surrounding UI labels, helper text, alerts, buttons, generation messages, validation messages, and screen copy should move through the localization layer.

## App Name

Set the app's user-facing display name to `Locket`, preferably through generated Info.plist build settings such as `INFOPLIST_KEY_CFBundleDisplayName`.

Do not rename the Xcode project, target, bundle identifier, test target, or Swift `@main` type as part of this pass unless the display name cannot otherwise be changed safely.

## Logo

Keep using the existing cherry resource if it is suitable, but update the logo view:

- Use a circular or near-circular mark.
- Center the cherry inside the mark.
- Use `scaledToFill` or explicit crop/alignment so the mark does not look pasted off-center.
- Add a subtle border matching the Figma reference.

If the current asset cannot be centered cleanly, create a simple SwiftUI cherry mark fallback for the small app-bar logo.

## Testing And Verification

Verification should include:

- Build the app for testing with the existing simulator build command.
- Unit-test the language selection helper for Korean and non-Korean locales.
- Preserve or update existing tests for the four-template catalog.
- Add focused tests for any extracted view model formatting helpers if they are introduced.
- Manually inspect SwiftUI preview or simulator screenshots if available.

The existing `xcodebuild test` limitation on this machine can remain documented if it still applies; `build-for-testing` should pass before implementation is considered complete.
