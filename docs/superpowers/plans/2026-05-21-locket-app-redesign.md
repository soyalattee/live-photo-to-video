# Locket App Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the visible SwiftUI app around the Figma Locket design, split the screen code into focused files, add Korean/English UI copy, and keep the existing media-to-video pipeline stable.

**Architecture:** Keep `AutoPhotosViewModel` as the state owner and move presentation into screen-level SwiftUI views. Add a small `L10n` layer for Korean versus English copy, a `LocketTheme` design system, and reusable Locket components for top bars, buttons, cards, inputs, rows, and toggles. The app display name changes through generated Info.plist settings while target, bundle identifier, and test target names remain unchanged.

**Tech Stack:** SwiftUI, PhotosUI, AVKit, Swift Testing, Xcode generated Info.plist build settings.

---

## File Structure

- Create `auto-photos/Localization/L10n.swift`
  - Device-language selection and typed UI strings.
- Create `auto-photos/Brand/LocketTheme.swift`
  - Locket color, typography, spacing, radius, and shadow tokens.
- Modify `auto-photos/Brand/BrandStyle.swift`
  - Keep compatibility for existing render/test code and update the app logo view to use Locket styling.
- Create `auto-photos/Views/LocketComponents.swift`
  - `LocketTopBar`, `LocketBottomActionBar`, `LocketPrimaryButtonStyle`, `LocketSecondaryButtonStyle`, `LocketTemplateCard`, `LocketInputField`, `LocketSequenceRow`, `LocketToggleCard`.
- Create `auto-photos/Views/TemplateGalleryScreen.swift`
  - Home/gallery screen matching the Figma `main` frame.
- Create `auto-photos/Views/MediaSequenceScreen.swift`
  - Selected media ordering and text customization screen matching the Figma `array` frame.
- Create `auto-photos/Views/VideoPreviewScreen.swift`
  - Preview/export screen matching the Figma `video download` frame.
- Create `auto-photos/Views/GenerationAndErrorScreens.swift`
  - Generation progress, loading overlay, and error screen in Locket styling.
- Modify `auto-photos/ContentView.swift`
  - Reduce it to app shell/routing, picker/sheet/alert presentation, and callbacks to `AutoPhotosViewModel`.
- Modify `auto-photos/AutoPhotosViewModel.swift`
  - Add localized summary, duration, and note helpers while keeping template-bound BGM semantics.
- Modify `auto-photos/AutoPhotosModels.swift`
  - Localize `MediaKind` display names and `GenerationStep` copy through `L10n`.
- Modify `auto-photos.xcodeproj/project.pbxproj`
  - Set `INFOPLIST_KEY_CFBundleDisplayName = Locket;` for app Debug and Release configurations.
- Modify `auto-photosTests/auto_photosTests.swift`
  - Add tests for language selection, media display names, generation copy, and template-bound BGM export text.

---

### Task 1: Localization Foundation

**Files:**
- Create: `auto-photos/Localization/L10n.swift`
- Modify: `auto-photosTests/auto_photosTests.swift`

- [ ] **Step 1: Write the failing localization tests**

Add these tests near the top of `auto-photosTests/auto_photosTests.swift`, after the `struct auto_photosTests {` line:

```swift
    @Test("L10n은 한국어면 한국어, 그 외 언어면 영어를 사용한다")
    func l10nLanguageSelection() {
        #expect(L10n.language(for: "ko") == .korean)
        #expect(L10n.language(for: "ko-KR") == .korean)
        #expect(L10n.language(for: "en") == .english)
        #expect(L10n.language(for: "ja") == .english)
        #expect(L10n(language: .korean).templateGallerySubtitle == "원하는 스타일을 골라 기억을 영상으로 남겨보세요.")
        #expect(L10n(language: .english).templateGallerySubtitle == "Choose a style and turn your memories into a video.")
    }

    @Test("L10n은 미디어 선택 CTA를 한국어와 영어로 제공한다")
    func l10nMediaPickerCTA() {
        #expect(L10n(language: .korean).chooseMedia == "미디어 선택하기")
        #expect(L10n(language: .english).chooseMedia == "Choose Media")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild build-for-testing -quiet -project auto-photos.xcodeproj -scheme auto-photos -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/auto-photos-derived
```

Expected: FAIL because `L10n` is not defined.

- [ ] **Step 3: Create the localization layer**

Create `auto-photos/Localization/L10n.swift`:

```swift
import Foundation

enum AppLanguage: Equatable, Sendable {
    case korean
    case english
}

struct L10n: Sendable {
    let language: AppLanguage

    init(language: AppLanguage = L10n.currentLanguage()) {
        self.language = language
    }

    static func currentLanguage(locale: Locale = .current) -> AppLanguage {
        language(for: locale.identifier)
    }

    static func language(for localeIdentifier: String?) -> AppLanguage {
        guard let normalized = localeIdentifier?.lowercased() else {
            return .english
        }

        return normalized == "ko" || normalized.hasPrefix("ko-") || normalized.hasPrefix("ko_") ? .korean : .english
    }

    var appName: String { "Locket" }
    var templateGalleryHeadlinePrefix: String { language == .korean ? "오늘을 어떤 무드로" : "How do you want to" }
    var templateGalleryHeadlineAccent: String { language == .korean ? "기억" : "remember" }
    var templateGalleryHeadlineSuffix: String { language == .korean ? "할까요?" : "today?" }
    var templateGallerySubtitle: String { language == .korean ? "원하는 스타일을 골라 기억을 영상으로 남겨보세요." : "Choose a style and turn your memories into a video." }
    var chooseMedia: String { language == .korean ? "미디어 선택하기" : "Choose Media" }
    var chooseTemplateFirst: String { language == .korean ? "템플릿을 먼저 선택하세요" : "Choose a template first" }
    var selectedTemplate: String { language == .korean ? "선택된 템플릿" : "Selected Template" }
    var mediaSequence: String { language == .korean ? "미디어 순서" : "Media Sequence" }
    var reselectMedia: String { language == .korean ? "미디어 다시 선택" : "Choose Media Again" }
    var generateVideo: String { language == .korean ? "영상 생성하기" : "Generate Video" }
    var preview: String { language == .korean ? "미리보기" : "Preview" }
    var musicOn: String { language == .korean ? "BGM 포함" : "Music On" }
    var textOn: String { language == .korean ? "텍스트 포함" : "Text On" }
    var saveToCameraRoll: String { language == .korean ? "사진 앱에 저장" : "Save to Camera Roll" }
    var share: String { language == .korean ? "공유하기" : "Share" }
    var retrySequence: String { language == .korean ? "순서 다시 보기" : "Review Sequence" }
    var cancel: String { language == .korean ? "취소" : "Cancel" }
    var close: String { language == .korean ? "닫기" : "Close" }
    var titleLabel: String { language == .korean ? "TITLE" : "TITLE" }
    var shortSentenceLabel: String { language == .korean ? "SHORT SENTENCE" : "SHORT SENTENCE" }
    var bottomCaptionLabel: String { language == .korean ? "BOTTOM TEXT" : "BOTTOM TEXT" }
    var mediaLoading: String { language == .korean ? "선택한 미디어를 템플릿에 맞게 준비하는 중이에요." : "Preparing your media for the selected template." }
    var errorTitle: String { language == .korean ? "문제가 생겼어요" : "Something went wrong" }
    var tryAgain: String { language == .korean ? "다시 시도" : "Try Again" }
    var startOver: String { language == .korean ? "처음으로" : "Start Over" }
    var templateBGMUnavailable: String { language == .korean ? "템플릿 BGM 파일을 다시 연결하면 BGM 옵션이 자동으로 활성화돼요." : "Reconnect the template BGM file to enable the music option." }
    var textUnavailable: String { language == .korean ? "이 템플릿은 텍스트 오버레이 없이 출력돼요." : "This template exports without text overlays." }
}
```

- [ ] **Step 4: Run build-for-testing**

Run the same command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add auto-photos/Localization/L10n.swift auto-photosTests/auto_photosTests.swift
git commit -m "feat: add locket localization layer"
```

---

### Task 2: Localized Model Copy

**Files:**
- Modify: `auto-photos/AutoPhotosModels.swift`
- Modify: `auto-photos/AutoPhotosViewModel.swift`
- Modify: `auto-photosTests/auto_photosTests.swift`

- [ ] **Step 1: Write failing tests for localized model strings**

Add:

```swift
    @Test("미디어 종류 이름은 L10n 언어에 맞게 표시된다")
    func mediaKindDisplayNamesAreLocalized() {
        let ko = L10n(language: .korean)
        let en = L10n(language: .english)

        #expect(MediaKind.photo.displayName(using: ko) == "사진")
        #expect(MediaKind.livePhoto.displayName(using: ko) == "Live Photo")
        #expect(MediaKind.video.displayName(using: ko) == "영상")
        #expect(MediaKind.photo.displayName(using: en) == "Photo")
        #expect(MediaKind.livePhoto.displayName(using: en) == "Live Photo")
        #expect(MediaKind.video.displayName(using: en) == "Video")
    }

    @Test("생성 단계 문구는 L10n 언어에 맞게 표시된다")
    func generationStepCopyIsLocalized() {
        let ko = L10n(language: .korean)
        let en = L10n(language: .english)

        #expect(GenerationStep.preparing.title(using: ko) == "소스를 정리하는 중")
        #expect(GenerationStep.preparing.title(using: en) == "Preparing sources")
        #expect(GenerationStep.preparing.subtitle(using: ko).contains("미디어"))
        #expect(GenerationStep.preparing.subtitle(using: en).contains("media"))
    }
```

- [ ] **Step 2: Run build-for-testing**

Expected: FAIL because `displayName(using:)`, `title(using:)`, and `subtitle(using:)` are not defined.

- [ ] **Step 3: Add localized model helpers**

Modify `MediaKind` in `auto-photos/AutoPhotosModels.swift`:

```swift
    var displayName: String {
        displayName(using: L10n())
    }

    func displayName(using l10n: L10n) -> String {
        switch (self, l10n.language) {
        case (.photo, .korean):
            return "사진"
        case (.photo, .english):
            return "Photo"
        case (.livePhoto, _):
            return "Live Photo"
        case (.video, .korean):
            return "영상"
        case (.video, .english):
            return "Video"
        }
    }
```

Modify `GenerationStep` in the same file:

```swift
    var title: String {
        title(using: L10n())
    }

    func title(using l10n: L10n) -> String {
        switch (self, l10n.language) {
        case (.preparing, .korean):
            return "소스를 정리하는 중"
        case (.preparing, .english):
            return "Preparing sources"
        case (.composing, .korean):
            return "템플릿 컷을 배치하는 중"
        case (.composing, .english):
            return "Arranging template cuts"
        case (.exporting, .korean):
            return "최종 영상을 굽는 중"
        case (.exporting, .english):
            return "Exporting final video"
        }
    }

    var subtitle: String {
        subtitle(using: L10n())
    }

    func subtitle(using l10n: L10n) -> String {
        switch (self, l10n.language) {
        case (.preparing, .korean):
            return "선택한 미디어를 템플릿 순서에 맞게 준비하고 있어요."
        case (.preparing, .english):
            return "Preparing your selected media for the template sequence."
        case (.composing, .korean):
            return "각 장면 길이와 비율을 맞춰 세로형 타임라인을 만들고 있어요."
        case (.composing, .english):
            return "Building a vertical timeline with the right timing and crop for each scene."
        case (.exporting, .korean):
            return "미리보기와 저장에 사용할 MP4를 내보내는 중이에요."
        case (.exporting, .english):
            return "Exporting the MP4 used for preview, saving, and sharing."
        }
    }
```

- [ ] **Step 4: Add localized ViewModel helpers**

Add to `AutoPhotosViewModel` without removing the existing computed properties yet:

```swift
    func localizedSelectionSummary(using l10n: L10n = L10n()) -> String {
        guard let selectedTemplate else {
            return l10n.chooseTemplateFirst
        }

        let unit = l10n.language == .korean ? "개" : "items"
        if selectedTemplate.usesSelectionCount {
            if let maximumSelectionCount = selectedTemplate.maximumSelectionCount {
                return "\(selectedItems.count)/\(maximumSelectionCount) \(unit)"
            }

            return "\(selectedItems.count) \(unit)"
        }

        return "\(selectedItems.count)/\(selectedTemplate.photoCount) \(unit)"
    }

    func localizedEstimatedDurationText(using l10n: L10n = L10n()) -> String {
        guard let selectedTemplate else {
            return l10n.language == .korean ? "템플릿을 먼저 고르면 예상 길이를 보여드려요." : "Choose a template to see the estimated duration."
        }

        if selectedTemplate.usesSelectionCount && selectedItems.isEmpty {
            return selectedTemplate.dynamicDurationHint ?? (l10n.language == .korean ? "선택한 미디어 길이를 자동으로 맞춰드려요." : "The selected media timing will be arranged automatically.")
        }

        let duration = selectedTemplate.usesSelectionCount ? selectedTemplate.totalDuration(for: selectedItems.count) : selectedTemplate.totalDuration
        return l10n.language == .korean ? String(format: "예상 길이 %.1f초", duration) : String(format: "Estimated %.1fs", duration)
    }

    func localizedExportSectionNote(using l10n: L10n = L10n()) -> String? {
        guard let selectedTemplate else {
            return nil
        }

        if selectedTemplate.supportsMusic && !selectedTemplate.isMusicAvailable {
            return l10n.templateBGMUnavailable
        }

        if !selectedTemplate.supportsText {
            return l10n.textUnavailable
        }

        return nil
    }
```

- [ ] **Step 5: Run build-for-testing**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add auto-photos/AutoPhotosModels.swift auto-photos/AutoPhotosViewModel.swift auto-photosTests/auto_photosTests.swift
git commit -m "feat: localize model and view model copy"
```

---

### Task 3: Locket Theme And Logo

**Files:**
- Create: `auto-photos/Brand/LocketTheme.swift`
- Modify: `auto-photos/Brand/BrandStyle.swift`
- Modify: `auto-photosTests/auto_photosTests.swift`

- [ ] **Step 1: Write failing theme tests**

Add:

```swift
    @Test("Locket 테마 토큰은 Figma 기준 색을 사용한다")
    func locketThemeUsesFigmaColors() {
        #expect(LocketTheme.hex.background == 0xFFF8F7)
        #expect(LocketTheme.hex.accent == 0xFF7597)
        #expect(LocketTheme.hex.ink == 0x23191A)
        #expect(LocketTheme.hex.surface == 0xFFF0F1)
    }
```

- [ ] **Step 2: Run build-for-testing**

Expected: FAIL because `LocketTheme` is not defined.

- [ ] **Step 3: Create the theme tokens**

Create `auto-photos/Brand/LocketTheme.swift`:

```swift
import SwiftUI

enum LocketTheme {
    enum hex {
        static let background = 0xFFF8F7
        static let accent = 0xFF7597
        static let ink = 0x23191A
        static let inkSoft = 0x534344
        static let surface = 0xFFF0F1
        static let border = 0xF4E4E6
        static let roseBorder = 0xDDBFC3
    }

    static let background = Color(hex: hex.background)
    static let accent = Color(hex: hex.accent)
    static let ink = Color(hex: hex.ink)
    static let inkSoft = Color(hex: hex.inkSoft)
    static let surface = Color(hex: hex.surface)
    static let border = Color(hex: hex.border)
    static let roseBorder = Color(hex: hex.roseBorder)
    static let card = Color.white
    static let shadow = Color.black.opacity(0.10)

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 8
    static let previewRadius: CGFloat = 32

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
```

- [ ] **Step 4: Update the logo view**

Replace `BrandLogoView` in `auto-photos/Brand/BrandStyle.swift` with:

```swift
struct BrandLogoView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(LocketTheme.ink)

            if let uiImage = BrandLogoAsset.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.88, height: size * 0.88)
                    .clipShape(Circle())
            } else {
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(LocketTheme.accent)
                    .offset(y: size * 0.02)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: LocketTheme.shadow, radius: size * 0.22, y: size * 0.10)
        .accessibilityLabel("Locket")
    }
}
```

- [ ] **Step 5: Run build-for-testing**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add auto-photos/Brand/LocketTheme.swift auto-photos/Brand/BrandStyle.swift auto-photosTests/auto_photosTests.swift
git commit -m "feat: add locket theme and logo"
```

---

### Task 4: Reusable Locket Components

**Files:**
- Create: `auto-photos/Views/LocketComponents.swift`
- Modify: `auto-photosTests/auto_photosTests.swift`

- [ ] **Step 1: Add a small test for template card metadata**

Add:

```swift
    @Test("Locket 카드 메타데이터는 기존 템플릿 이름을 유지한다")
    func locketTemplateCardsKeepCurrentTemplateNames() {
        #expect(TemplateCatalog.templates.map(\.name).contains("Lock Screen Log"))
        #expect(TemplateCatalog.templates.map(\.name).contains("All Photos Flow"))
    }
```

- [ ] **Step 2: Create reusable components**

Create `auto-photos/Views/LocketComponents.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct LocketTopBar: View {
    let title: String
    var showsBackButton = false
    var onBack: (() -> Void)?

    var body: some View {
        HStack {
            if showsBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LocketTheme.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    BrandLogoView(size: 32)
                    Text(title)
                        .font(LocketTheme.serif(28, weight: .bold))
                        .tracking(-1.0)
                        .foregroundStyle(LocketTheme.ink)
                }
            }

            Spacer(minLength: 0)

            if showsBackButton {
                Text(title)
                    .font(LocketTheme.sans(20, weight: .heavy))
                    .tracking(-1.0)
                    .foregroundStyle(LocketTheme.ink)
                Spacer(minLength: 0)
            }

            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(LocketTheme.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LocketTheme.pagePadding)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.55))
    }
}

struct LocketBottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            content
                .padding(.horizontal, LocketTheme.pagePadding)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(LocketTheme.background.opacity(0.92))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(LocketTheme.border)
                        .frame(height: 1)
                }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct LocketPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LocketTheme.sans(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(LocketTheme.accent.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: LocketTheme.controlRadius, style: .continuous))
            .shadow(color: LocketTheme.accent.opacity(0.20), radius: 14, y: 8)
    }
}

struct LocketSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LocketTheme.sans(14, weight: .bold))
            .foregroundStyle(LocketTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: LocketTheme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LocketTheme.controlRadius, style: .continuous).stroke(LocketTheme.roseBorder, lineWidth: 2))
    }
}

struct LocketTemplateCard: View {
    let template: VideoTemplate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [template.theme.accent.color, template.theme.secondaryAccent.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(colors: [.clear, .black.opacity(0.80)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(LocketTheme.serif(18))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(template.tagline)
                        .font(LocketTheme.sans(11))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
                .padding(16)
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous)
                    .stroke(isSelected ? LocketTheme.accent : .clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.templateCard.\(template.id)")
    }
}

struct LocketInputField: View {
    let label: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(LocketTheme.sans(12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: 0xA83255))
            TextField(label, text: $text, axis: axis)
                .font(LocketTheme.sans(16, weight: .semibold))
                .foregroundStyle(LocketTheme.ink)
                .padding(.horizontal, 17)
                .padding(.vertical, 13)
                .background(LocketTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(LocketTheme.roseBorder.opacity(0.40)))
        }
    }
}
```

Append the row and toggle components in the same file:

```swift
struct LocketSequenceRow: View {
    let item: SelectedMediaItem
    let l10n: L10n
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("\(item.selectionIndex + 1)")
                .font(LocketTheme.sans(12, weight: .bold))
                .foregroundStyle(LocketTheme.inkSoft)
                .frame(width: 18)

            Image(uiImage: item.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(l10n.language == .korean ? "\(item.selectionIndex + 1)번째 미디어" : "Media \(item.selectionIndex + 1)")
                    .font(LocketTheme.sans(14, weight: .medium))
                    .foregroundStyle(LocketTheme.ink)
                    .lineLimit(1)
                Text(item.kind.displayName(using: l10n))
                    .font(LocketTheme.sans(12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(LocketTheme.inkSoft)
            }

            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LocketTheme.inkSoft)
            }
            .buttonStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LocketTheme.inkSoft)
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LocketTheme.roseBorder.opacity(0.20)))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }
}

struct LocketToggleCard: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: { if isEnabled { onToggle(!isOn) } }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(LocketTheme.accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(LocketTheme.accent)
                    )
                Text(title)
                    .font(LocketTheme.sans(11, weight: .bold))
                    .foregroundStyle(LocketTheme.ink)
                Spacer(minLength: 0)
            }
            .padding(13)
            .background(Color.white.opacity(isEnabled ? 1 : 0.56), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(LocketTheme.roseBorder.opacity(0.30)))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
```

- [ ] **Step 3: Run build-for-testing**

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add auto-photos/Views/LocketComponents.swift auto-photosTests/auto_photosTests.swift
git commit -m "feat: add locket ui components"
```

---

### Task 5: Template Gallery Screen And App Shell

**Files:**
- Create: `auto-photos/Views/TemplateGalleryScreen.swift`
- Modify: `auto-photos/ContentView.swift`

- [ ] **Step 1: Create the gallery screen**

Create `auto-photos/Views/TemplateGalleryScreen.swift`:

```swift
import SwiftUI

struct TemplateGalleryScreen: View {
    let l10n: L10n
    let templates: [VideoTemplate]
    let selectedTemplate: VideoTemplate?
    let canOpenPicker: Bool
    let onSelectTemplate: (VideoTemplate) -> Void
    let onOpenPicker: () -> Void

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.templateGalleryHeadlinePrefix)
                            .font(LocketTheme.serif(28, weight: .bold))
                            .foregroundStyle(LocketTheme.ink)
                        HStack(spacing: 6) {
                            Text(l10n.templateGalleryHeadlineAccent)
                                .foregroundStyle(LocketTheme.accent)
                            Text(l10n.templateGalleryHeadlineSuffix)
                                .foregroundStyle(LocketTheme.ink)
                        }
                        .font(LocketTheme.serif(28, weight: .bold))
                        Text(l10n.templateGallerySubtitle)
                            .font(LocketTheme.serif(16))
                            .foregroundStyle(LocketTheme.inkSoft)
                    }
                    .padding(.top, 96)
                    .padding(.horizontal, LocketTheme.pagePadding)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(templates) { template in
                            LocketTemplateCard(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id,
                                onSelect: { onSelectTemplate(template) }
                            )
                        }
                    }
                    .padding(.horizontal, LocketTheme.pagePadding)
                    .padding(.bottom, 128)
                }
            }

            VStack(spacing: 0) {
                LocketTopBar(title: l10n.appName)
                Spacer()
            }

            LocketBottomActionBar {
                Button(action: onOpenPicker) {
                    Label(selectedTemplate == nil ? l10n.chooseTemplateFirst : l10n.chooseMedia, systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(LocketPrimaryButtonStyle())
                .opacity(canOpenPicker ? 1 : 0.50)
                .disabled(!canOpenPicker)
                .accessibilityIdentifier("home.makeVideoButton")
            }
        }
    }
}
```

- [ ] **Step 2: Replace home routing in `ContentView`**

In `ContentView`, add:

```swift
    private let l10n = L10n()
```

Replace the existing `body` container with an app-shell container that lets each screen own its full layout:

```swift
    var body: some View {
        ZStack {
            contentSection

            if viewModel.isResolvingSelection {
                LocketLoadingOverlay(l10n: l10n)
            }
        }
        .alert(item: $viewModel.alertInfo) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(l10n.language == .korean ? "확인" : "OK"))
            )
        }
        .sheet(isPresented: $isPickerPresented) {
            MediaPickerSheet(selectionLimit: viewModel.pickerSelectionLimit) { results in
                Task {
                    await viewModel.handlePickerResults(results)
                }
            }
            .id(viewModel.pickerResetToken)
        }
        .sheet(item: $viewModel.shareSheetPayload, onDismiss: viewModel.dismissShareSheet) { payload in
            ShareSheetView(items: [payload.url])
        }
    }
```

Replace the `.idle` branch in `contentSection` with:

```swift
            case .idle:
                TemplateGalleryScreen(
                    l10n: l10n,
                    templates: viewModel.templates,
                    selectedTemplate: viewModel.selectedTemplate,
                    canOpenPicker: viewModel.canOpenPicker,
                    onSelectTemplate: viewModel.selectTemplate,
                    onOpenPicker: {
                        isPickerPresented = true
                    }
                )
```

Remove `onCreateTemplate`, `onEditTemplate`, and `onDeleteTemplate` from the home call site. Keep the old custom template sheet code in place for this task so the diff stays bounded; it will be removed in Task 8.

- [ ] **Step 3: Run build-for-testing**

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add auto-photos/Views/TemplateGalleryScreen.swift auto-photos/ContentView.swift
git commit -m "feat: add locket template gallery"
```

---

### Task 6: Media Sequence Screen

**Files:**
- Create: `auto-photos/Views/MediaSequenceScreen.swift`
- Modify: `auto-photos/ContentView.swift`

- [ ] **Step 1: Create the media sequence screen**

Create `auto-photos/Views/MediaSequenceScreen.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct MediaSequenceScreen: View {
    let l10n: L10n
    let template: VideoTemplate
    @Binding var cinematicTextCustomization: TemplateCinematicTextCustomization?
    let items: [SelectedMediaItem]
    let summary: String
    let estimatedDurationText: String
    let validationMessage: String?
    let canGenerate: Bool
    let onMoveItem: (SelectedMediaItem, SelectedMediaItem) -> Void
    let onDeleteItem: (SelectedMediaItem) -> Void
    let onGenerate: () -> Void
    let onReselect: () -> Void
    let onReset: () -> Void

    @State private var draggedItem: SelectedMediaItem?
    @State private var pendingDeleteItem: SelectedMediaItem?

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    textSection
                    sequenceSection
                    actionSection
                }
                .padding(.horizontal, LocketTheme.pagePadding)
                .padding(.top, 92)
                .padding(.bottom, 40)
            }

            VStack(spacing: 0) {
                LocketTopBar(title: l10n.appName, showsBackButton: true, onBack: onReset)
                Spacer()
            }
        }
        .alert(item: $pendingDeleteItem) { item in
            Alert(
                title: Text(l10n.language == .korean ? "미디어 제거" : "Remove Media"),
                message: Text(l10n.language == .korean ? "\(item.selectionIndex + 1)번째 미디어를 순서에서 제거할까요?" : "Remove media \(item.selectionIndex + 1) from the sequence?"),
                primaryButton: .destructive(Text(l10n.language == .korean ? "제거" : "Remove")) { onDeleteItem(item) },
                secondaryButton: .cancel(Text(l10n.cancel))
            )
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let binding = customizationBinding {
                if template.lockScreenOverlay != nil {
                    LocketInputField(label: l10n.bottomCaptionLabel, text: binding.secondaryText, axis: .vertical)
                } else {
                    LocketInputField(label: l10n.titleLabel, text: binding.primaryText, axis: .vertical)
                    LocketInputField(label: l10n.shortSentenceLabel, text: binding.secondaryText, axis: .vertical)
                }
            }
        }
    }

    private var sequenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                Text(l10n.mediaSequence)
                    .font(LocketTheme.sans(20, weight: .semibold))
                    .foregroundStyle(LocketTheme.ink)
                Spacer()
                Text(summary)
                    .font(LocketTheme.sans(12, weight: .semibold))
                    .foregroundStyle(LocketTheme.inkSoft)
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    LocketSequenceRow(item: item, l10n: l10n) {
                        pendingDeleteItem = item
                    }
                    .onDrag {
                        draggedItem = item
                        return NSItemProvider(object: NSString(string: item.id.uuidString))
                    }
                    .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(targetItem: item, draggedItem: $draggedItem, onMoveItem: onMoveItem))
                }

                Button(action: onReselect) {
                    Label(l10n.reselectMedia, systemImage: "plus")
                        .font(LocketTheme.sans(12, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color(hex: 0xA83255))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LocketTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LocketTheme.roseBorder, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(estimatedDurationText)
                .font(LocketTheme.sans(12, weight: .semibold))
                .foregroundStyle(LocketTheme.inkSoft)

            if let validationMessage {
                Text(validationMessage)
                    .font(LocketTheme.sans(14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xA83255))
                    .accessibilityIdentifier("selection.validationText")
            }

            Button(action: onGenerate) {
                Label(l10n.generateVideo, systemImage: "movieclapper.fill")
            }
            .buttonStyle(LocketPrimaryButtonStyle())
            .opacity(canGenerate ? 1 : 0.50)
            .disabled(!canGenerate)
            .accessibilityIdentifier("selection.generateButton")
        }
    }

    private var customizationBinding: Binding<TemplateCinematicTextCustomization>? {
        guard template.supportsCinematicTextCustomization else {
            return nil
        }

        return Binding(
            get: {
                cinematicTextCustomization ?? template.defaultCinematicTextCustomization ?? TemplateCinematicTextCustomization(
                    primaryText: "",
                    secondaryText: "",
                    primaryFontName: TemplateFontPreset.defaultPreset.fontName,
                    secondaryFontName: TemplateFontPreset.defaultPreset.fontName,
                    textColor: ColorToken(red: 1, green: 1, blue: 1),
                    shadowColor: ColorToken(red: 0, green: 0, blue: 0)
                )
            },
            set: { cinematicTextCustomization = $0 }
        )
    }
}
```

- [ ] **Step 2: Route selection review to the new screen**

Replace the `.selectionReview` branch in `ContentView` with:

```swift
            case .selectionReview:
                if let selectedTemplate = viewModel.selectedTemplate {
                    MediaSequenceScreen(
                        l10n: l10n,
                        template: selectedTemplate,
                        cinematicTextCustomization: $viewModel.cinematicTextCustomization,
                        items: viewModel.selectedItems,
                        summary: viewModel.localizedSelectionSummary(using: l10n),
                        estimatedDurationText: viewModel.localizedEstimatedDurationText(using: l10n),
                        validationMessage: viewModel.validationMessage,
                        canGenerate: viewModel.canGenerate,
                        onMoveItem: viewModel.moveItem,
                        onDeleteItem: viewModel.removeItem,
                        onGenerate: viewModel.startGeneration,
                        onReselect: {
                            isPickerPresented = true
                        },
                        onReset: viewModel.resetToHome
                    )
                }
```

- [ ] **Step 3: Run build-for-testing**

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add auto-photos/Views/MediaSequenceScreen.swift auto-photos/ContentView.swift
git commit -m "feat: add locket media sequence screen"
```

---

### Task 7: Preview, Generation, Error Screens

**Files:**
- Create: `auto-photos/Views/VideoPreviewScreen.swift`
- Create: `auto-photos/Views/GenerationAndErrorScreens.swift`
- Modify: `auto-photos/ContentView.swift`

- [ ] **Step 1: Create the preview screen**

Create `auto-photos/Views/VideoPreviewScreen.swift`:

```swift
import SwiftUI

struct VideoPreviewScreen: View {
    let l10n: L10n
    let template: VideoTemplate
    let video: GeneratedVideo
    let exportOptions: VideoRenderOptions
    let statusMessage: String?
    let note: String?
    let isSaving: Bool
    let isSharing: Bool
    let onToggleMusic: (Bool) -> Void
    let onToggleText: (Bool) -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    let onRetry: () -> Void
    let onReset: () -> Void

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    LoopingVideoPlayerView(url: video.url)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: LocketTheme.previewRadius, style: .continuous))
                        .shadow(color: Color.black.opacity(0.10), radius: 40, y: 20)
                        .padding(.top, 96)

                    controls
                }
                .padding(.horizontal, LocketTheme.pagePadding)
                .padding(.bottom, 34)
            }

            VStack(spacing: 0) {
                LocketTopBar(title: l10n.appName, showsBackButton: true, onBack: onReset)
                Spacer()
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                LocketToggleCard(title: l10n.musicOn, systemImage: "music.note", isOn: exportOptions.includesMusic, isEnabled: template.isMusicAvailable, onToggle: onToggleMusic)
                LocketToggleCard(title: l10n.textOn, systemImage: "captions.bubble", isOn: exportOptions.includesText, isEnabled: template.supportsText, onToggle: onToggleText)
            }
            .padding(16)
            .background(LocketTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let note {
                Text(note)
                    .font(LocketTheme.sans(13))
                    .foregroundStyle(LocketTheme.inkSoft)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(LocketTheme.sans(14, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2F7D55))
            }

            Button(action: onSave) {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Label(l10n.saveToCameraRoll, systemImage: "square.and.arrow.down.fill")
                }
            }
            .buttonStyle(LocketPrimaryButtonStyle())
            .disabled(isSaving || isSharing)
            .accessibilityIdentifier("preview.saveButton")

            Button(action: onShare) {
                if isSharing {
                    ProgressView().tint(LocketTheme.ink)
                } else {
                    Label(l10n.share, systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(LocketSecondaryButtonStyle())
            .disabled(isSaving || isSharing)
            .accessibilityIdentifier("preview.shareButton")

            Button(l10n.retrySequence, action: onRetry)
                .font(LocketTheme.sans(14, weight: .bold))
                .foregroundStyle(LocketTheme.inkSoft)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("preview.retryButton")
        }
    }
}
```

- [ ] **Step 2: Create generation and error screens**

Create `auto-photos/Views/GenerationAndErrorScreens.swift`:

```swift
import SwiftUI

struct GenerationOverlay: View {
    let l10n: L10n
    let step: GenerationStep
    let templateName: String
    let count: Int
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(LocketTheme.accent)
                    .scaleEffect(1.5)
                Text(step.title(using: l10n))
                    .font(LocketTheme.serif(28, weight: .bold))
                    .foregroundStyle(LocketTheme.ink)
                    .accessibilityIdentifier("generation.statusText")
                Text(step.subtitle(using: l10n))
                    .font(LocketTheme.sans(15))
                    .foregroundStyle(LocketTheme.inkSoft)
                    .multilineTextAlignment(.center)
                Text(l10n.language == .korean ? "\(templateName)에 \(count)개의 미디어를 배치하고 있어요." : "Arranging \(count) media items in \(templateName).")
                    .font(LocketTheme.sans(13, weight: .semibold))
                    .foregroundStyle(LocketTheme.inkSoft)
                Button(l10n.cancel, action: onCancel)
                    .buttonStyle(LocketSecondaryButtonStyle())
                    .accessibilityIdentifier("generation.cancelButton")
            }
            .padding(24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, LocketTheme.pagePadding)
        }
    }
}

struct LocketErrorScreen: View {
    let l10n: L10n
    let message: String
    let onRecover: () -> Void
    let onReset: () -> Void

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(LocketTheme.accent)
                Text(l10n.errorTitle)
                    .font(LocketTheme.serif(28, weight: .bold))
                    .foregroundStyle(LocketTheme.ink)
                Text(message)
                    .font(LocketTheme.sans(15))
                    .foregroundStyle(LocketTheme.inkSoft)
                Button(l10n.tryAgain, action: onRecover)
                    .buttonStyle(LocketPrimaryButtonStyle())
                    .accessibilityIdentifier("error.retryButton")
                Button(l10n.startOver, action: onReset)
                    .buttonStyle(LocketSecondaryButtonStyle())
            }
            .padding(24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, LocketTheme.pagePadding)
        }
    }
}

struct LocketLoadingOverlay: View {
    let l10n: L10n

    var body: some View {
        ZStack {
            LocketTheme.ink.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(LocketTheme.accent)
                Text(l10n.mediaLoading)
                    .font(LocketTheme.sans(14, weight: .bold))
                    .foregroundStyle(LocketTheme.ink)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
```

- [ ] **Step 3: Route preview, generation, error, and loading states**

Replace the corresponding `ContentView` branches:

```swift
            case let .generating(step):
                GenerationOverlay(
                    l10n: l10n,
                    step: step,
                    templateName: viewModel.selectedTemplate?.name ?? "Locket",
                    count: viewModel.selectedItems.count,
                    onCancel: viewModel.cancelGeneration
                )
            case let .preview(video):
                if let selectedTemplate = viewModel.selectedTemplate {
                    VideoPreviewScreen(
                        l10n: l10n,
                        template: selectedTemplate,
                        video: video,
                        exportOptions: viewModel.exportOptions,
                        statusMessage: viewModel.toastMessage,
                        note: viewModel.localizedExportSectionNote(using: l10n),
                        isSaving: viewModel.isSaving,
                        isSharing: viewModel.isSharing,
                        onToggleMusic: viewModel.updateExportMusicOption,
                        onToggleText: viewModel.updateExportTextOption,
                        onSave: { Task { await viewModel.saveGeneratedVideo() } },
                        onShare: { Task { await viewModel.prepareShareVideo() } },
                        onRetry: viewModel.returnToSelectionReview,
                        onReset: viewModel.resetToHome
                    )
                }
            case let .error(message):
                LocketErrorScreen(
                    l10n: l10n,
                    message: message,
                    onRecover: viewModel.recoverFromError,
                    onReset: viewModel.resetToHome
                )
```

Replace the loading overlay call:

```swift
            if viewModel.isResolvingSelection {
                LocketLoadingOverlay(l10n: l10n)
            }
```

- [ ] **Step 4: Run build-for-testing**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add auto-photos/Views/VideoPreviewScreen.swift auto-photos/Views/GenerationAndErrorScreens.swift auto-photos/ContentView.swift
git commit -m "feat: add locket preview and status screens"
```

---

### Task 8: Remove Old Home/Editor Surfaces From App Shell

**Files:**
- Modify: `auto-photos/ContentView.swift`
- Modify: `auto-photosTests/auto_photosTests.swift`

- [ ] **Step 1: Add guard tests for four-template-only experience**

Add:

```swift
    @Test("홈 경험은 기본 네 가지 템플릿만 사용한다")
    func homeExperienceUsesOnlyBuiltInTemplates() {
        #expect(TemplateCatalog.templates.count == 4)
        #expect(TemplateCatalog.templates.allSatisfy { !$0.isCustomTemplate })
    }
```

- [ ] **Step 2: Remove unused custom-template UI state from `ContentView`**

Remove these members and sheet wiring from `ContentView`:

```swift
    @State private var templateEditorContext: TemplateEditorContext?
```

Remove the `.sheet(item: $templateEditorContext)` block that presents `TemplateEditorView`.

Remove the `TemplateEditorContext`, `HomeStateView`, `TemplateCardView`, `TemplateActionPanelView`, `TemplateEditorView`, and `TemplateEditorCard` declarations from `ContentView.swift` after confirming the new screens compile without them.

- [ ] **Step 3: Keep custom template services untouched**

Leave these files unchanged in this task:

```text
auto-photos/Services/DefaultTemplateLibraryService.swift
auto-photos/Templates/TemplateEditorModels.swift
```

The service/model code can remain dormant because the user only asked to hide the create/edit flow from the app experience.

- [ ] **Step 4: Run build-for-testing**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add auto-photos/ContentView.swift auto-photosTests/auto_photosTests.swift
git commit -m "refactor: hide custom template editor"
```

---

### Task 9: App Display Name And Permission Copy

**Files:**
- Modify: `auto-photos.xcodeproj/project.pbxproj`

- [ ] **Step 1: Update generated Info.plist build settings**

In both app target build configurations `B3CD00CB2F93EC2F00A5F8BD /* Debug */` and `B3CD00CC2F93EC2F00A5F8BD /* Release */`, add:

```text
INFOPLIST_KEY_CFBundleDisplayName = Locket;
```

Also update the photo library usage description strings to include videos:

```text
INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "생성한 영상을 사진 앱에 저장하기 위해 권한이 필요합니다.";
INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "사진, Live Photo, 영상을 선택해 영상을 만들기 위해 사진 접근이 필요합니다.";
```

- [ ] **Step 2: Run build-for-testing**

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add auto-photos.xcodeproj/project.pbxproj
git commit -m "chore: set locket display name"
```

---

### Task 10: Final Cleanup And Verification

**Files:**
- Inspect and modify when the commands in this task report a concrete compiler or search issue:
  - `auto-photos/ContentView.swift`
  - `auto-photos/Views/LocketComponents.swift`
  - `auto-photos/Views/TemplateGalleryScreen.swift`
  - `auto-photos/Views/MediaSequenceScreen.swift`
  - `auto-photos/Views/VideoPreviewScreen.swift`
  - `auto-photos/Views/GenerationAndErrorScreens.swift`
  - `auto-photos/Brand/LocketTheme.swift`
  - `auto-photos/Brand/BrandStyle.swift`
  - `auto-photos/Localization/L10n.swift`
  - `auto-photosTests/auto_photosTests.swift`

- [ ] **Step 1: Search for old user-facing app brand and narrow media copy**

Run:

```bash
rg "auto-photos|Cherry-toned|Template-Driven|사진 추가하기|사진 선택하기|Choose Photos|daily recap|프리미엄.*BGM|고급.*BGM|BGM 선택|BGM 변경" auto-photos docs/superpowers/specs/2026-05-21-locket-app-redesign-design.md
```

Expected: no matches in user-facing app UI. Matches in project names, test target names, source headers, and historical docs are acceptable only when they are not visible to users.

- [ ] **Step 2: Run final build verification**

Run:

```bash
xcodebuild build-for-testing -quiet -project auto-photos.xcodeproj -scheme auto-photos -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/auto-photos-derived
```

Expected: command exits 0.

- [ ] **Step 3: Run targeted Swift tests when the local simulator allows it**

Run:

```bash
xcodebuild test -quiet -project auto-photos.xcodeproj -scheme auto-photos -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /private/tmp/auto-photos-derived
```

Expected on a fully available simulator: PASS. If this machine still blocks simulator tests, capture the exact failure and report that `build-for-testing` passed.

- [ ] **Step 4: Manual visual inspection**

Launch the app in Xcode or a simulator and check:

```text
Home: Locket logo/title, Korean or English headline, four template cards, no custom template add/edit entry.
Sequence: selected media rows, media type labels for Photo/Live Photo/Video, reorder handle, reselect row, generate CTA.
Preview: 9:16 preview, BGM toggle as template-bound on/off, text toggle, save/share actions.
Brand: app display name appears as Locket on the installed app.
```

- [ ] **Step 5: Commit final cleanup**

```bash
git status --short
git add auto-photos auto-photosTests auto-photos.xcodeproj/project.pbxproj
git commit -m "chore: verify locket redesign"
```

Skip the final cleanup commit when there are no remaining changes after the verification steps.
