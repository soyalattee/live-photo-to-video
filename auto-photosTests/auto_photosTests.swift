//
//  auto_photosTests.swift
//  auto-photosTests
//
//  Created by 박소연 on 4/19/26.
//

import Foundation
import Testing
import UIKit
@testable import auto_photos

@MainActor
struct auto_photosTests {
    @Test("Locket 테마 토큰은 Figma 기준 색을 사용한다")
    func locketThemeUsesFigmaColors() {
        #expect(LocketTheme.hex.background == 0xFFF8F7)
        #expect(LocketTheme.hex.accent == 0xFF7597)
        #expect(LocketTheme.hex.ink == 0x23191A)
        #expect(LocketTheme.hex.surface == 0xFFF0F1)
    }

    @Test("Locket 카드 메타데이터는 기존 템플릿 이름을 유지한다")
    func locketTemplateCardsKeepCurrentTemplateNames() {
        #expect(TemplateCatalog.templates.map(\.name).contains("Lock Screen Log"))
        #expect(TemplateCatalog.templates.map(\.name).contains("All Photos Flow"))
    }

    @Test("L10n은 한국어면 한국어, 그 외 언어면 영어를 사용한다")
    func l10nLanguageSelection() {
        #expect(L10n.language(for: "ko") == .korean)
        #expect(L10n.language(for: "ko-KR") == .korean)
        #expect(L10n.language(for: "ko_KR") == .korean)
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

    @Test("저장과 공유 상태 문구는 L10n 언어에 맞게 표시된다")
    func previewStatusCopyIsLocalized() {
        let ko = L10n(language: .korean)
        let en = L10n(language: .english)

        #expect(ko.saveSuccessMessage == "선택한 옵션으로 사진 앱에 저장했어요.")
        #expect(en.saveSuccessMessage == "Saved to Photos with the selected options.")
        #expect(ko.saveFailureTitle == "저장 실패")
        #expect(en.saveFailureTitle == "Save Failed")
        #expect(ko.shareFailureTitle == "공유 준비 실패")
        #expect(en.shareFailureTitle == "Could Not Prepare Share")
    }

    @Test("AutoPhotosError는 L10n 언어에 맞게 사용자 메시지를 제공한다")
    func autoPhotosErrorMessagesAreLocalized() {
        let ko = L10n(language: .korean)
        let en = L10n(language: .english)

        #expect(AutoPhotosError.exportFailed.userMessage(using: ko) == "영상 생성에 실패했어요. 다시 시도해주세요.")
        #expect(AutoPhotosError.exportFailed.userMessage(using: en) == "Video generation failed. Please try again.")
        #expect(AutoPhotosError.savePermissionDenied.userMessage(using: ko) == "사진 앱에 저장하려면 저장 권한이 필요해요.")
        #expect(AutoPhotosError.savePermissionDenied.userMessage(using: en) == "Allow Photos access to save this video.")
    }

    @Test("ViewModel은 미리보기 상태와 오류 상태 문구를 L10n 언어로 만든다")
    func previewAndErrorRouteCopyUsesInjectedL10nLanguage() async throws {
        let template = TemplateCatalog.templates[0]
        let generator = MockVideoGenerationService(
            result: .success(
                GeneratedVideo(
                    url: tempURL("preview-localized"),
                    duration: template.totalDuration,
                    renderOptions: template.previewRenderOptions
                )
            )
        )
        let viewModel = AutoPhotosViewModel(
            photoLibraryService: MockPhotoLibraryService(),
            videoGenerationService: generator,
            videoSaveService: MockVideoSaveService(error: AutoPhotosError.saveFailed),
            templateLibraryService: MockTemplateLibraryService(),
            l10n: L10n(language: .english)
        )

        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection(makeSelection(count: template.photoCount))
        viewModel.startGeneration()

        #expect(await eventually {
            if case .preview = viewModel.generationState {
                return true
            }

            return false
        })

        await viewModel.saveGeneratedVideo()

        #expect(viewModel.alertInfo?.title == "Save Failed")
        #expect(viewModel.alertInfo?.message == "Saving failed. Check your available storage and Photos access.")

        let failingGenerator = MockVideoGenerationService(result: .failure(AutoPhotosError.exportFailed))
        let failingViewModel = makeViewModel(generator: failingGenerator, l10n: L10n(language: .english))
        failingViewModel.selectTemplate(template)
        failingViewModel.applyResolvedSelection(makeSelection(count: template.photoCount))
        failingViewModel.startGeneration()

        #expect(await eventually {
            if case let .error(message) = failingViewModel.generationState {
                return message == "Video generation failed. Please try again."
            }

            return false
        })
    }

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

    @Test("선택 요약은 ViewModel 헬퍼에서 L10n 언어에 맞게 표시된다")
    func localizedSelectionSummaryUsesL10nLanguage() {
        let viewModel = makeViewModel()
        let en = L10n(language: .english)

        #expect(viewModel.localizedSelectionSummary(using: en) == en.chooseTemplateFirst)

        viewModel.selectTemplate(VideoTemplate.lockScreenLog)
        viewModel.applyResolvedSelection([makeItem(index: 0, kind: .photo)])

        #expect(viewModel.localizedSelectionSummary(using: en) == "1 item")
    }

    @Test("동적 템플릿 예상 길이 문구는 ViewModel 헬퍼에서 L10n 언어에 맞게 표시된다")
    func localizedDynamicDurationTextUsesL10nLanguage() {
        let viewModel = makeViewModel()
        viewModel.selectTemplate(VideoTemplate.lockScreenLog)

        #expect(viewModel.localizedEstimatedDurationText(using: L10n(language: .korean)).contains("첫 컷"))
        #expect(viewModel.localizedEstimatedDurationText(using: L10n(language: .english)) == "The selected media timing will be arranged automatically.")
    }

    @Test("내보내기 안내는 BGM 누락을 텍스트 안내보다 먼저 표시한다")
    func localizedExportNotePrioritizesMissingBGM() {
        let viewModel = makeViewModel()
        let en = L10n(language: .english)
        let template = VideoTemplate(
            id: "missing-bgm-with-text",
            name: "Missing BGM With Text",
            tagline: "tag",
            description: "desc",
            photoCount: 1,
            clipDurations: [1.0],
            audioTrack: .bundled(title: "Missing", resourceName: "missing-bgm-resource", fileExtension: "wav"),
            textOverlay: TemplateTextOverlay(
                text: "caption",
                startTime: 0,
                endTime: 1,
                fontName: "AvenirNext-Bold",
                fontSize: 48,
                position: TemplateTextPosition(x: 0.5, y: 0.5)
            ),
            theme: .brandDefault
        )

        viewModel.selectTemplate(template)

        #expect(viewModel.localizedExportSectionNote(using: en) == en.templateBGMUnavailable)
    }

    @Test("내보내기 안내는 텍스트 미지원 템플릿을 L10n 언어에 맞게 표시한다")
    func localizedExportNoteUsesL10nTextUnavailable() {
        let viewModel = makeViewModel()
        let en = L10n(language: .english)
        let template = VideoTemplate(
            id: "no-audio-no-text",
            name: "No Audio No Text",
            tagline: "tag",
            description: "desc",
            photoCount: 1,
            clipDurations: [1.0],
            audioTrack: nil,
            textOverlay: nil,
            theme: .brandDefault
        )

        viewModel.selectTemplate(template)

        #expect(viewModel.localizedExportSectionNote(using: en) == en.textUnavailable)
    }

    @Test("템플릿은 정확한 사진 수와 총 길이를 관리한다")
    func templateValidationAndDuration() {
        let template = TemplateCatalog.templates[0]

        #expect(template.photoCount == 10)
        #expect(template.validationMessage(for: 9) == "10장 중 9장 선택됨")
        #expect(template.validationMessage(for: 10) == nil)
        #expect(template.validationMessage(for: 11) == "10장까지만 사용할 수 있어요.")
        #expect(abs(template.totalDuration - 20.9) < 0.0001)
    }

    @Test("템플릿 선택 후 사진 순서를 다시 배치할 수 있다")
    func selectionCanBeReordered() {
        let viewModel = makeViewModel()
        let template = TemplateCatalog.templates[0]
        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection(makeSelection(count: template.photoCount))

        let firstItem = viewModel.selectedItems[0]
        let targetItem = viewModel.selectedItems[3]

        viewModel.moveItem(firstItem, before: targetItem)

        #expect(viewModel.selectedItems[2].id == firstItem.id)
        #expect(viewModel.selectedItems.map(\.selectionIndex) == Array(0..<template.photoCount))
    }

    @Test("선택한 미디어를 순서의 마지막으로 이동할 수 있다")
    func selectionCanMoveItemToEnd() {
        let viewModel = makeViewModel()
        let template = TemplateCatalog.templates[0]
        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection(makeSelection(count: template.photoCount))

        let originalIDs = viewModel.selectedItems.map(\.id)
        let firstItem = viewModel.selectedItems[0]

        viewModel.moveItemToEnd(firstItem)

        #expect(viewModel.selectedItems.map(\.id) == Array(originalIDs.dropFirst()) + [firstItem.id])
        #expect(viewModel.selectedItems.map(\.selectionIndex) == Array(0..<template.photoCount))
    }

    @Test("정상 생성 시 preview 상태로 전이한다")
    func generationSuccessTransitionsToPreview() async throws {
        let template = TemplateCatalog.templates[0]
        let generator = MockVideoGenerationService(
            result: .success(
                GeneratedVideo(
                    url: tempURL("success"),
                    duration: template.totalDuration,
                    renderOptions: template.previewRenderOptions
                )
            )
        )
        let viewModel = makeViewModel(generator: generator)

        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection(makeSelection(count: template.photoCount))
        viewModel.startGeneration()

        #expect(await eventually {
            if case .preview = viewModel.generationState {
                return true
            }

            return false
        })
    }

    @Test("생성 취소 시 selectionReview 상태로 돌아간다")
    func cancellationTransitionsBackToSelectionReview() async throws {
        let template = TemplateCatalog.templates[0]
        let generator = MockVideoGenerationService(result: .cancellable)
        let viewModel = makeViewModel(generator: generator)

        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection(makeSelection(count: template.photoCount))
        viewModel.startGeneration()

        #expect(await eventually {
            if case .generating = viewModel.generationState {
                return true
            }

            return false
        })

        viewModel.cancelGeneration()

        #expect(await eventually { viewModel.generationState == .selectionReview })
    }

    @Test("저장 실패 시 preview 상태는 유지되고 alert가 표시된다")
    func saveFailureKeepsPreviewState() async throws {
        let template = TemplateCatalog.templates[0]
        let generator = MockVideoGenerationService(
            result: .success(
                GeneratedVideo(
                    url: tempURL("preview"),
                    duration: template.totalDuration,
                    renderOptions: template.previewRenderOptions
                )
            )
        )
        let saver = MockVideoSaveService(error: AutoPhotosError.saveFailed)
        let viewModel = AutoPhotosViewModel(
            photoLibraryService: MockPhotoLibraryService(),
            videoGenerationService: generator,
            videoSaveService: saver,
            templateLibraryService: MockTemplateLibraryService(),
            l10n: L10n(language: .korean)
        )

        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection(makeSelection(count: template.photoCount))
        viewModel.startGeneration()

        #expect(await eventually {
            if case .preview = viewModel.generationState {
                return true
            }

            return false
        })

        await viewModel.saveGeneratedVideo()

        #expect({
            if case .preview = viewModel.generationState {
                return true
            }

            return false
        }())
        #expect(viewModel.alertInfo?.title == "저장 실패")
    }

    @Test("미리보기와 다른 내보내기 옵션이면 별도 렌더를 사용한다")
    func exportVariantsAreRenderedSeparately() async throws {
        let template = VideoTemplate(
            id: "text-template",
            name: "Text Template",
            tagline: "tag",
            description: "desc",
            photoCount: 10,
            clipDurations: Array(repeating: 2.0, count: 10),
            audioTrack: nil,
            textOverlay: TemplateTextOverlay(
                text: "miniLog",
                startTime: 1,
                endTime: 8,
                fontName: "AvenirNext-Bold",
                fontSize: 74,
                position: TemplateTextPosition(x: 0.5, y: 0.18)
            ),
            theme: TemplateCatalog.templates[0].theme
        )
        let generator = MockVideoGenerationService(
            result: .dynamic { request in
                GeneratedVideo(
                    url: tempURL(request.renderOptions.includesText ? "text-on" : "text-off"),
                    duration: request.template.totalDuration,
                    renderOptions: request.renderOptions
                )
            }
        )
        let viewModel = makeViewModel(generator: generator)

        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection(makeSelection(count: template.photoCount))
        viewModel.startGeneration()

        #expect(await eventually {
            if case .preview = viewModel.generationState {
                return true
            }

            return false
        })

        viewModel.updateExportTextOption(false)
        await viewModel.prepareShareVideo()

        #expect(viewModel.shareSheetPayload != nil)
        #expect(generator.generatedRequests.count == 2)
        #expect(generator.generatedRequests.last?.renderOptions.includesText == false)
    }

    @Test("잠금화면 로그 템플릿은 모든 컷을 첫 컷 1.5초 이후 1초씩 사용한다")
    func lockScreenLogTemplateUsesUnlimitedSelectionWithRequestedDurations() {
        let template = VideoTemplate.lockScreenLog

        #expect(template.usesSelectionCount)
        #expect(template.photoCount == 0)
        #expect(template.resolvedClipDurations(for: 1) == [1.5])
        #expect(template.resolvedClipDurations(for: 4) == [1.5, 1.0, 1.0, 1.0])
        #expect(template.totalDuration(for: 4) == 4.5)
        #expect(template.lockScreenOverlay != nil)
        #expect(template.supportsCinematicTextCustomization)
        #expect(template.audioTrack == .bundled(title: "Tak Before Dawn", resourceName: "Tak Before Dawn", fileExtension: "wav"))
    }

    @Test("잠금화면 로그 템플릿은 기본 카탈로그에 포함된다")
    func lockScreenLogTemplateIsInCatalog() {
        #expect(TemplateCatalog.templates.contains { $0.id == VideoTemplate.lockScreenLog.id })
    }

    @Test("기본 카탈로그는 유지할 네 가지 템플릿만 노출한다")
    func templateCatalogOnlyShowsApprovedTemplates() {
        #expect(TemplateCatalog.templates.map(\.id) == [
            "restaurant-recommendation",
            "lock-screen-log",
            "life-in-fraems",
            "all-photos-flow",
        ])
    }

    @Test("All Photos Flow는 Saltair Drive 번들 오디오를 사용한다")
    func allPhotosFlowUsesSaltairDriveAudio() {
        #expect(VideoTemplate.allPhotosFlow.audioTrack == .bundled(
            title: "Saltair Drive",
            resourceName: "Saltair Drive",
            fileExtension: "wav"
        ))
    }

    @Test("잠금화면 오버레이는 첫 컷에만 지연 등장하고 이후 컷은 즉시 교체된다")
    func lockScreenOverlayRevealTimingOnlyDelaysFirstClip() throws {
        let overlay = try #require(VideoTemplate.lockScreenLog.lockScreenOverlay)

        #expect(overlay.textRevealStartTime(for: .date, clipStart: 0, isFirstClip: true) == 0.1)
        #expect(overlay.textRevealStartTime(for: .time, clipStart: 0, isFirstClip: true) == 0.2)
        #expect(overlay.textRevealStartTime(for: .bottomText, clipStart: 0, isFirstClip: true) == 0.5)
        #expect(overlay.textRevealStartTime(for: .date, clipStart: 1.5, isFirstClip: false) == 1.5)
        #expect(overlay.textRevealStartTime(for: .time, clipStart: 1.5, isFirstClip: false) == 1.5)
        #expect(overlay.textRevealStartTime(for: .bottomText, clipStart: 1.5, isFirstClip: false) == 1.5)
    }

    @Test("잠금화면 오버레이 좌표는 영상 합성 좌표계에 맞게 세로 반전된다")
    func lockScreenOverlayConvertsTopLeftLayoutToVideoLayerCoordinates() {
        let topLeftFrame = CGRect(x: 80, y: 1518, width: 920, height: 74)
        let converted = TemplateLockScreenOverlay.videoLayerFrame(
            fromTopLeftFrame: topLeftFrame,
            renderHeight: 1920
        )

        #expect(converted == CGRect(x: 80, y: 328, width: 920, height: 74))
        #expect(TemplateLockScreenOverlay.videoLayerY(fromTopLeftCenterY: 1756.8, renderHeight: 1920) == 163.2)
    }

    @Test("잠금화면 날짜와 하단 문구는 폰트가 잘리지 않도록 여유 높이를 사용한다")
    func lockScreenOverlayTextFramesHaveVerticalPadding() {
        let renderSize = CGSize(width: 1080, height: 1920)

        #expect(TemplateLockScreenOverlay.dateTopLeftFrame(renderSize: renderSize).height >= 82)
        #expect(TemplateLockScreenOverlay.bottomTextTopLeftFrame(renderSize: renderSize).height >= 104)
    }

    @Test("잠금화면 날짜 폰트와 하단 문구 opacity는 템플릿 설정값을 따른다")
    func lockScreenOverlayTypographySettings() {
        #expect(TemplateLockScreenOverlay.dateFontSize == 56)
        #expect(TemplateLockScreenOverlay.bottomTextLayerOpacity == 0.9)
    }

    @Test("잠금화면 텍스트는 컷 끝에서 흐려지지 않고 즉시 교체된다")
    func lockScreenOverlayOpacityDoesNotFadeOutBeforeCutEnd() {
        let timing = TemplateLockScreenOverlay.opacityTiming(
            startTime: 1.5,
            endTime: 2.5,
            totalDuration: 4.5,
            shouldFadeIn: false
        )

        #expect(timing.enterProgress == timing.startProgress)
        #expect(timing.exitProgress == timing.endProgress)
    }

    @Test("선택 순서를 바꿔도 리소스 생성일을 보존한다")
    func selectionReindexingPreservesCreationDate() {
        let viewModel = makeViewModel()
        let template = VideoTemplate.lockScreenLog
        let firstDate = makeDate(year: 2026, month: 5, day: 13, hour: 18, minute: 3)
        let secondDate = makeDate(year: 2026, month: 5, day: 13, hour: 21, minute: 10)
        let thirdDate = makeDate(year: 2026, month: 5, day: 14, hour: 12, minute: 10)

        viewModel.selectTemplate(template)
        viewModel.applyResolvedSelection([
            makeItem(index: 0, kind: .photo, creationDate: firstDate),
            makeItem(index: 1, kind: .livePhoto, creationDate: secondDate),
            makeItem(index: 2, kind: .video, creationDate: thirdDate),
        ])

        viewModel.moveItem(viewModel.selectedItems[0], before: viewModel.selectedItems[2])

        #expect(viewModel.selectedItems.map(\.creationDate) == [secondDate, firstDate, thirdDate])
        #expect(viewModel.selectedItems.map(\.selectionIndex) == [0, 1, 2])
    }

    @Test("잠금화면 로그 템플릿은 사용자 하단 문구를 생성 요청에 전달한다")
    func lockScreenLogBottomTextCustomizationTravelsWithGenerationRequest() async {
        let template = VideoTemplate.lockScreenLog
        let generator = MockVideoGenerationService(
            result: .dynamic { request in
                GeneratedVideo(
                    url: tempURL("lock-screen-log"),
                    duration: request.template.totalDuration(for: request.items.count),
                    renderOptions: request.renderOptions
                )
            }
        )
        let viewModel = makeViewModel(generator: generator)

        viewModel.selectTemplate(template)
        viewModel.cinematicTextCustomization?.secondaryText = "여름맞이 ootd 브이로그"
        viewModel.applyResolvedSelection(makeSelection(count: 3))
        viewModel.startGeneration()

        #expect(await eventually {
            if case .preview = viewModel.generationState {
                return true
            }

            return false
        })
        #expect(generator.generatedRequests.first?.cinematicTextCustomization?.secondaryText == "여름맞이 ootd 브이로그")
    }
}

@MainActor
private func makeViewModel(generator: MockVideoGenerationService = MockVideoGenerationService(result: .success(
    GeneratedVideo(url: tempURL("default"), duration: TemplateCatalog.templates[0].totalDuration, renderOptions: TemplateCatalog.templates[0].previewRenderOptions)
)), l10n: L10n = L10n()) -> AutoPhotosViewModel {
    AutoPhotosViewModel(
        photoLibraryService: MockPhotoLibraryService(),
        videoGenerationService: generator,
        videoSaveService: MockVideoSaveService(),
        templateLibraryService: MockTemplateLibraryService(),
        l10n: l10n
    )
}

private final class MockPhotoLibraryService: PhotoLibraryService {
    func resolveSelection(from assetIdentifiers: [String]) async throws -> [SelectedMediaItem] {
        []
    }
}

private final class MockVideoGenerationService: VideoGenerationService {
    enum Behavior {
        case success(GeneratedVideo)
        case failure(Error)
        case cancellable
        case dynamic((VideoGenerationRequest) -> GeneratedVideo)
    }

    private let result: Behavior
    private(set) var generatedRequests: [VideoGenerationRequest] = []

    init(result: Behavior) {
        self.result = result
    }

    func generateVideo(
        from request: VideoGenerationRequest,
        progress: @escaping @Sendable (GenerationStep) -> Void
    ) async throws -> GeneratedVideo {
        generatedRequests.append(request)
        progress(.preparing)

        switch result {
        case let .success(video):
            progress(.exporting)
            return video
        case let .failure(error):
            throw error
        case .cancellable:
            progress(.composing)
            while true {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        case let .dynamic(builder):
            progress(.exporting)
            return builder(request)
        }
    }

    func cancelGeneration() {}
}

private struct MockVideoSaveService: VideoSaveService {
    var error: Error?

    func saveVideo(at url: URL) async throws {
        if let error {
            throw error
        }
    }
}

private struct MockTemplateLibraryService: TemplateLibraryService {
    func loadCustomTemplates() -> [VideoTemplate] {
        []
    }

    func saveCustomTemplate(_ template: VideoTemplate) throws {}

    func deleteCustomTemplate(id: String) throws {}

    func importAudioTrack(from sourceURL: URL) throws -> TemplateAudioTrack {
        .imported(title: sourceURL.lastPathComponent, resourceName: "mock", fileExtension: "m4a")
    }
}

private func makeSelection(count: Int) -> [SelectedMediaItem] {
    (0..<count).map { index in
        makeItem(index: index, kind: index.isMultiple(of: 2) ? .photo : .livePhoto)
    }
}

private func makeItem(index: Int, kind: MediaKind, creationDate: Date? = nil) -> SelectedMediaItem {
    SelectedMediaItem(
        assetLocalIdentifier: "asset-\(index)",
        kind: kind,
        selectionIndex: index,
        creationDate: creationDate,
        thumbnail: solidImage()
    )
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

private func solidImage() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
        UIColor.systemPink.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
    }
}

private func tempURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("\(name).mp4")
}

private func eventually(
    retries: Int = 30,
    condition: @escaping @MainActor () -> Bool
) async -> Bool {
    for _ in 0..<retries {
        if await condition() {
            return true
        }

        await Task.yield()
    }

    return await condition()
}
