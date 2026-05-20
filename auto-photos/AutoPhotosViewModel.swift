//
//  AutoPhotosViewModel.swift
//  auto-photos
//
//  Created by Codex on 4/19/26.
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class AutoPhotosViewModel: ObservableObject {
    private struct VideoRenderCacheKey: Hashable {
        let options: VideoRenderOptions
        let cinematicTextCustomization: TemplateCinematicTextCustomization?
    }

    @Published var generationState: GenerationState = .idle
    @Published var templates: [VideoTemplate] = []
    @Published var selectedTemplate: VideoTemplate?
    @Published var cinematicTextCustomization: TemplateCinematicTextCustomization?
    @Published var selectedItems: [SelectedMediaItem] = []
    @Published var exportOptions: VideoRenderOptions = .none
    @Published var alertInfo: AlertInfo?
    @Published var toastMessage: String?
    @Published var shareSheetPayload: ShareSheetPayload?
    @Published var isSaving = false
    @Published var isSharing = false
    @Published var isResolvingSelection = false
    @Published var pickerResetToken = UUID()

    private let photoLibraryService: PhotoLibraryService
    private let videoGenerationService: VideoGenerationService
    private let videoSaveService: VideoSaveService
    private let templateLibraryService: TemplateLibraryService

    private var recoveryDestination: ErrorRecoveryDestination = .home
    private var generationTask: Task<Void, Never>?
    private var renderedVideos: [VideoRenderCacheKey: GeneratedVideo] = [:]

    init(
        photoLibraryService: PhotoLibraryService,
        videoGenerationService: VideoGenerationService,
        videoSaveService: VideoSaveService,
        templateLibraryService: TemplateLibraryService
    ) {
        self.photoLibraryService = photoLibraryService
        self.videoGenerationService = videoGenerationService
        self.videoSaveService = videoSaveService
        self.templateLibraryService = templateLibraryService
        self.templates = Self.mergeTemplates(
            builtInTemplates: TemplateCatalog.templates,
            customTemplates: templateLibraryService.loadCustomTemplates()
        )
    }

    var pickerSelectionLimit: Int {
        SelectionRules.pickerLimit(for: selectedTemplate)
    }

    var validationMessage: String? {
        guard let selectedTemplate else {
            return nil
        }

        return selectedTemplate.validationMessage(for: selectedItems.count)
    }

    var selectionSummary: String {
        guard let selectedTemplate else {
            return "템플릿을 선택해주세요"
        }

        if selectedTemplate.usesSelectionCount {
            if let maximumSelectionCount = selectedTemplate.maximumSelectionCount {
                return "\(selectedItems.count)/\(maximumSelectionCount)장 선택"
            }

            return "\(selectedItems.count)장 선택"
        }

        return "\(selectedItems.count)/\(selectedTemplate.photoCount)장 선택"
    }

    func localizedSelectionSummary(using l10n: L10n = L10n()) -> String {
        guard let selectedTemplate else {
            return l10n.chooseTemplateFirst
        }

        let unit = l10n.language == .korean ? "개" : selectedItems.count == 1 ? "item" : "items"
        if selectedTemplate.usesSelectionCount {
            if let maximumSelectionCount = selectedTemplate.maximumSelectionCount {
                return "\(selectedItems.count)/\(maximumSelectionCount) \(unit)"
            }

            return "\(selectedItems.count) \(unit)"
        }

        return "\(selectedItems.count)/\(selectedTemplate.photoCount) \(unit)"
    }

    var estimatedDurationText: String {
        guard let selectedTemplate else {
            return "템플릿을 먼저 고르면 예상 길이를 보여드려요."
        }

        if selectedTemplate.usesSelectionCount {
            guard !selectedItems.isEmpty else {
                return selectedTemplate.dynamicDurationHint ?? "선택한 모든 사진 길이를 자동으로 맞춰드려요."
            }

            return String(format: "예상 길이 %.1f초", selectedTemplate.totalDuration(for: selectedItems.count))
        }

        return String(format: "예상 길이 %.1f초", selectedTemplate.totalDuration)
    }

    func localizedEstimatedDurationText(using l10n: L10n = L10n()) -> String {
        guard let selectedTemplate else {
            return l10n.language == .korean ? "템플릿을 먼저 고르면 예상 길이를 보여드려요." : "Choose a template to see the estimated duration."
        }

        if selectedTemplate.usesSelectionCount && selectedItems.isEmpty {
            return l10n.language == .korean
                ? selectedTemplate.dynamicDurationHint ?? "선택한 미디어 길이를 자동으로 맞춰드려요."
                : "The selected media timing will be arranged automatically."
        }

        let duration = selectedTemplate.usesSelectionCount ? selectedTemplate.totalDuration(for: selectedItems.count) : selectedTemplate.totalDuration
        return l10n.language == .korean ? String(format: "예상 길이 %.1f초", duration) : String(format: "Estimated %.1fs", duration)
    }

    var canGenerate: Bool {
        selectedTemplate != nil && validationMessage == nil && !selectedItems.isEmpty && !isGenerating
    }

    var canOpenPicker: Bool {
        selectedTemplate != nil && !isGenerating
    }

    var generatedVideo: GeneratedVideo? {
        if case let .preview(video) = generationState {
            return video
        }

        guard let selectedTemplate else {
            return nil
        }

        return renderedVideos[cacheKey(for: selectedTemplate.previewRenderOptions)]
    }

    var currentErrorMessage: String? {
        if case let .error(message) = generationState {
            return message
        }

        return nil
    }

    var exportSectionNote: String? {
        guard let selectedTemplate else {
            return nil
        }

        if selectedTemplate.supportsMusic && !selectedTemplate.isMusicAvailable {
            return "템플릿 BGM 파일을 다시 연결하면 노래 옵션이 자동으로 활성화돼요."
        }

        if !selectedTemplate.supportsText {
            return "이 템플릿은 텍스트 오버레이 없이 출력돼요."
        }

        return nil
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

    private var isGenerating: Bool {
        if case .generating = generationState {
            return true
        }

        return false
    }

    func selectTemplate(_ template: VideoTemplate) {
        let shouldResetSelection = selectedTemplate?.id != template.id

        selectedTemplate = template
        cinematicTextCustomization = template.defaultCinematicTextCustomization
        exportOptions = template.previewRenderOptions
        toastMessage = nil
        alertInfo = nil

        if shouldResetSelection {
            selectedItems = []
            generationState = .idle
            pickerResetToken = UUID()
            cleanupRenderedVideos()
        }
    }

    func saveCustomTemplate(from draft: TemplateDraft) throws {
        let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw TemplateDraftError.emptyTitle
        }

        guard (1...SelectionRules.librarySelectionUpperBound).contains(draft.photoCount) else {
            throw TemplateDraftError.invalidPhotoCount
        }

        let clipDurations = draft.parsedClipDurations
        guard clipDurations.count == draft.photoCount else {
            throw TemplateDraftError.invalidClipDurations(expected: draft.photoCount, actual: clipDurations.count)
        }

        guard clipDurations.allSatisfy({ $0 > 0 }) else {
            throw TemplateDraftError.nonPositiveDuration
        }

        let audioTrack: TemplateAudioTrack?
        if let audioImportURL = draft.audioImportURL {
            audioTrack = try templateLibraryService.importAudioTrack(from: audioImportURL)
        } else {
            audioTrack = draft.existingAudioTrack
        }

        let textOverlay: TemplateTextOverlay?
        if draft.includesText {
            guard !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TemplateDraftError.emptyText
            }

            guard draft.textEndTime > draft.textStartTime else {
                throw TemplateDraftError.invalidTextTiming
            }

            textOverlay = TemplateTextOverlay(
                text: draft.text,
                startTime: draft.textStartTime,
                endTime: draft.textEndTime,
                fontName: draft.fontName,
                fontSize: draft.fontSize,
                position: TemplateTextPosition(x: draft.textPositionX, y: draft.textPositionY)
            )
        } else {
            textOverlay = nil
        }

        let template = VideoTemplate(
            id: draft.templateID ?? "custom-\(UUID().uuidString)",
            name: normalizedTitle,
            tagline: "\(draft.photoCount)컷 커스텀 템플릿",
            description: draft.summaryDescription,
            photoCount: draft.photoCount,
            clipDurations: clipDurations,
            audioTrack: audioTrack,
            textOverlay: textOverlay,
            theme: .brandDefault
        )

        try templateLibraryService.saveCustomTemplate(template)
        refreshTemplates()
        selectTemplate(template)
    }

    func deleteCustomTemplate(_ template: VideoTemplate) throws {
        guard template.isCustomTemplate else {
            return
        }

        try templateLibraryService.deleteCustomTemplate(id: template.id)
        refreshTemplates()

        if selectedTemplate?.id == template.id {
            resetToHome()
        }
    }

    func handlePickerResults(_ results: [PHPickerResult]) async {
        guard let selectedTemplate else {
            alertInfo = AlertInfo(title: "템플릿 선택", message: AutoPhotosError.templateMissing.localizedDescription)
            return
        }

        guard !results.isEmpty else {
            if selectedItems.isEmpty {
                generationState = .idle
            }
            return
        }

        isResolvingSelection = true
        defer { isResolvingSelection = false }

        do {
            try await ensurePhotoLibraryReadAccess()

            let identifiers = try results.map { result in
                guard let identifier = result.assetIdentifier else {
                    throw AutoPhotosError.assetIdentifierMissing
                }

                return identifier
            }

            let resolvedItems = try await photoLibraryService.resolveSelection(from: identifiers)
            let limitedItems = selectedTemplate.usesSelectionCount
                ? Array(resolvedItems.prefix(selectedTemplate.maximumSelectionCount ?? resolvedItems.count))
                : Array(resolvedItems.prefix(selectedTemplate.photoCount))
            applyResolvedSelection(limitedItems)
        } catch is CancellationError {
            return
        } catch {
            handleSelectionResolutionFailure(error)
        }
    }

    private func ensurePhotoLibraryReadAccess() async throws {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let resolvedStatus: PHAuthorizationStatus

        switch currentStatus {
        case .authorized, .limited:
            resolvedStatus = currentStatus
        case .notDetermined:
            resolvedStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        default:
            resolvedStatus = currentStatus
        }

        guard resolvedStatus == .authorized || resolvedStatus == .limited else {
            throw AutoPhotosError.assetNotFound
        }
    }

    func applyResolvedSelection(_ items: [SelectedMediaItem]) {
        selectedItems = reindexed(items.sorted { $0.selectionIndex < $1.selectionIndex })
        toastMessage = nil
        alertInfo = nil

        if selectedItems.isEmpty {
            generationState = .idle
        } else {
            generationState = .selectionReview
        }
    }

    func moveItem(_ draggedItem: SelectedMediaItem, before targetItem: SelectedMediaItem) {
        guard draggedItem.id != targetItem.id else {
            return
        }

        guard
            let sourceIndex = selectedItems.firstIndex(where: { $0.id == draggedItem.id }),
            let destinationIndex = selectedItems.firstIndex(where: { $0.id == targetItem.id })
        else {
            return
        }

        var updatedItems = selectedItems
        let movingItem = updatedItems.remove(at: sourceIndex)
        let insertionIndex = destinationIndex > sourceIndex ? max(destinationIndex - 1, 0) : destinationIndex
        updatedItems.insert(movingItem, at: insertionIndex)
        selectedItems = reindexed(updatedItems)
    }

    func removeItem(_ item: SelectedMediaItem) {
        selectedItems.removeAll { $0.id == item.id }
        selectedItems = reindexed(selectedItems)

        if selectedItems.isEmpty {
            generationState = .idle
        } else if case .preview = generationState {
            generationState = .selectionReview
        }

        cleanupRenderedVideos()
        toastMessage = nil
    }

    func handleSelectionResolutionFailure(_ error: Error) {
        selectedItems = []
        recoveryDestination = .home
        generationState = .error(message: error.localizedDescription)
        pickerResetToken = UUID()
    }

    func startGeneration() {
        guard let selectedTemplate else {
            alertInfo = AlertInfo(title: "템플릿 선택", message: AutoPhotosError.templateMissing.localizedDescription)
            return
        }

        guard canGenerate else {
            alertInfo = AlertInfo(
                title: "선택 확인",
                message: validationMessage ?? AutoPhotosError.invalidSelection.localizedDescription
            )
            return
        }

        toastMessage = nil
        alertInfo = nil
        cleanupRenderedVideos()

        generationTask?.cancel()
        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let video = try await videoGenerationService.generateVideo(
                    from: VideoGenerationRequest(
                        items: selectedItems,
                        template: selectedTemplate,
                        renderOptions: selectedTemplate.previewRenderOptions,
                        cinematicTextCustomization: cinematicTextCustomization
                    ),
                    progress: { [weak self] step in
                        Task { @MainActor in
                            self?.generationState = .generating(step: step)
                        }
                    }
                )

                guard !Task.isCancelled else {
                    return
                }

                storeRenderedVideo(video)
                exportOptions = selectedTemplate.previewRenderOptions
                generationState = .preview(video)
            } catch is CancellationError {
                generationState = selectedItems.isEmpty ? .idle : .selectionReview
            } catch {
                recoveryDestination = .selectionReview
                generationState = .error(message: error.localizedDescription)
            }
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        videoGenerationService.cancelGeneration()
        generationState = selectedItems.isEmpty ? .idle : .selectionReview
    }

    func updateExportMusicOption(_ enabled: Bool) {
        guard selectedTemplate?.isMusicAvailable == true else {
            exportOptions.includesMusic = false
            return
        }

        exportOptions.includesMusic = enabled
    }

    func updateExportTextOption(_ enabled: Bool) {
        guard selectedTemplate?.supportsText == true else {
            exportOptions.includesText = false
            return
        }

        exportOptions.includesText = enabled
    }

    func updateCinematicTextCustomization(_ customization: TemplateCinematicTextCustomization) {
        cinematicTextCustomization = customization
    }

    func saveGeneratedVideo() async {
        guard case .preview = generationState else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let outputVideo = try await video(for: exportOptions)
            try await videoSaveService.saveVideo(at: outputVideo.url)
            toastMessage = "선택한 옵션으로 사진 앱에 저장했어요."
        } catch {
            alertInfo = AlertInfo(title: "저장 실패", message: error.localizedDescription)
        }
    }

    func prepareShareVideo() async {
        guard case .preview = generationState else {
            return
        }

        isSharing = true
        defer { isSharing = false }

        do {
            let outputVideo = try await video(for: exportOptions)
            shareSheetPayload = ShareSheetPayload(url: outputVideo.url)
        } catch {
            alertInfo = AlertInfo(title: "공유 준비 실패", message: error.localizedDescription)
        }
    }

    func dismissShareSheet() {
        shareSheetPayload = nil
    }

    func returnToSelectionReview() {
        generationState = selectedItems.isEmpty ? .idle : .selectionReview
        toastMessage = nil
    }

    func resetToHome() {
        generationTask?.cancel()
        generationTask = nil
        videoGenerationService.cancelGeneration()
        selectedTemplate = nil
        cinematicTextCustomization = nil
        selectedItems = []
        exportOptions = .none
        generationState = .idle
        toastMessage = nil
        alertInfo = nil
        shareSheetPayload = nil
        pickerResetToken = UUID()
        cleanupRenderedVideos()
    }

    func recoverFromError() {
        switch recoveryDestination {
        case .home:
            selectedTemplate = nil
            cinematicTextCustomization = nil
            generationState = .idle
        case .selectionReview:
            generationState = selectedItems.isEmpty ? .idle : .selectionReview
        }
    }

    private func video(for options: VideoRenderOptions) async throws -> GeneratedVideo {
        if let cachedVideo = renderedVideos[cacheKey(for: options)] {
            return cachedVideo
        }

        guard let selectedTemplate else {
            throw AutoPhotosError.templateMissing
        }

        guard validationMessage == nil else {
            throw AutoPhotosError.invalidSelection
        }

        let renderedVideo = try await videoGenerationService.generateVideo(
            from: VideoGenerationRequest(
                items: selectedItems,
                template: selectedTemplate,
                renderOptions: options,
                cinematicTextCustomization: cinematicTextCustomization
            ),
            progress: { _ in }
        )
        storeRenderedVideo(renderedVideo)
        return renderedVideo
    }

    private func storeRenderedVideo(_ video: GeneratedVideo) {
        renderedVideos[cacheKey(for: video.renderOptions)] = video
    }

    private func cacheKey(for options: VideoRenderOptions) -> VideoRenderCacheKey {
        VideoRenderCacheKey(
            options: options,
            cinematicTextCustomization: cinematicTextCustomization
        )
    }

    private func cleanupRenderedVideos() {
        let urls = Set(renderedVideos.values.map(\.url))

        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }

        renderedVideos.removeAll()
    }

    private func reindexed(_ items: [SelectedMediaItem]) -> [SelectedMediaItem] {
        items.enumerated().map { index, item in
            SelectedMediaItem(
                id: item.id,
                assetLocalIdentifier: item.assetLocalIdentifier,
                kind: item.kind,
                selectionIndex: index,
                creationDate: item.creationDate,
                thumbnail: item.thumbnail
            )
        }
    }

    private func refreshTemplates() {
        templates = Self.mergeTemplates(
            builtInTemplates: TemplateCatalog.templates,
            customTemplates: templateLibraryService.loadCustomTemplates()
        )
    }

    private static func mergeTemplates(
        builtInTemplates: [VideoTemplate],
        customTemplates: [VideoTemplate]
    ) -> [VideoTemplate] {
        builtInTemplates + customTemplates
    }
}

@MainActor
enum AppBootstrap {
    static func makeViewModel() -> AutoPhotosViewModel {
        if let scenario = currentUITestScenario() {
            return makeUITestViewModel(for: scenario)
        }

        return AutoPhotosViewModel(
            photoLibraryService: DefaultPhotoLibraryService(),
            videoGenerationService: DefaultVideoGenerationService(),
            videoSaveService: DefaultVideoSaveService(),
            templateLibraryService: DefaultTemplateLibraryService()
        )
    }

    private static func currentUITestScenario() -> UITestScenario? {
        let arguments = Set(ProcessInfo.processInfo.arguments)

        if arguments.contains("UITEST_SCENARIO_INVALID_SELECTION") {
            return .invalidSelection
        }

        if arguments.contains("UITEST_SCENARIO_GENERATING") {
            return .generating
        }

        if arguments.contains("UITEST_SCENARIO_PREVIEW") {
            return .preview
        }

        if arguments.contains("UITEST_SCENARIO_ERROR") {
            return .error
        }

        if arguments.contains("UITEST_SCENARIO_HOME") {
            return .home
        }

        return nil
    }

    private static func makeUITestViewModel(for scenario: UITestScenario) -> AutoPhotosViewModel {
        let viewModel = AutoPhotosViewModel(
            photoLibraryService: StubPhotoLibraryService(),
            videoGenerationService: StubVideoGenerationService(),
            videoSaveService: StubVideoSaveService(),
            templateLibraryService: StubTemplateLibraryService()
        )

        let template = TemplateCatalog.templates.first(where: { !$0.usesSelectionCount }) ?? TemplateCatalog.templates[0]

        switch scenario {
        case .home:
            viewModel.generationState = .idle
        case .invalidSelection:
            viewModel.selectTemplate(template)
            viewModel.applyResolvedSelection([
                SelectedMediaItem.preview(index: 0, kind: .photo, color: .systemPink),
                SelectedMediaItem.preview(index: 1, kind: .livePhoto, color: .systemOrange),
                SelectedMediaItem.preview(index: 2, kind: .photo, color: .systemBlue),
            ])
        case .generating:
            viewModel.selectTemplate(template)
            viewModel.applyResolvedSelection(makePreviewSelection(count: template.photoCount))
            viewModel.generationState = .generating(step: .composing)
        case .preview:
            viewModel.selectTemplate(template)
            viewModel.applyResolvedSelection(makePreviewSelection(count: template.photoCount))
            let previewURL = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-preview.mp4")
            viewModel.generationState = .preview(
                GeneratedVideo(
                    url: previewURL,
                    duration: template.totalDuration,
                    renderOptions: template.previewRenderOptions
                )
            )
        case .error:
            viewModel.selectTemplate(template)
            viewModel.applyResolvedSelection(makePreviewSelection(count: template.photoCount))
            viewModel.generationState = .error(message: "영상 생성에 실패했어요. 다시 시도해주세요.")
        }

        return viewModel
    }
}

private struct StubPhotoLibraryService: PhotoLibraryService {
    func resolveSelection(from assetIdentifiers: [String]) async throws -> [SelectedMediaItem] {
        []
    }
}

private struct StubTemplateLibraryService: TemplateLibraryService {
    func loadCustomTemplates() -> [VideoTemplate] {
        []
    }

    func saveCustomTemplate(_ template: VideoTemplate) throws {}

    func deleteCustomTemplate(id: String) throws {}

    func importAudioTrack(from sourceURL: URL) throws -> TemplateAudioTrack {
        .imported(title: sourceURL.deletingPathExtension().lastPathComponent, resourceName: "stub-audio", fileExtension: "m4a")
    }
}

private final class StubVideoGenerationService: VideoGenerationService {
    func generateVideo(
        from request: VideoGenerationRequest,
        progress: @escaping @Sendable (GenerationStep) -> Void
    ) async throws -> GeneratedVideo {
        progress(.preparing)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stub-preview.mp4")
        return GeneratedVideo(
            url: url,
            duration: request.template.totalDuration,
            renderOptions: request.renderOptions
        )
    }

    func cancelGeneration() {}
}

private struct StubVideoSaveService: VideoSaveService {
    func saveVideo(at url: URL) async throws {}
}

private extension SelectedMediaItem {
    static func preview(index: Int, kind: MediaKind, color: UIColor) -> SelectedMediaItem {
        SelectedMediaItem(
            assetLocalIdentifier: "preview-\(index)",
            kind: kind,
            selectionIndex: index,
            thumbnail: .solidColor(color)
        )
    }
}

private func makePreviewSelection(count: Int) -> [SelectedMediaItem] {
    let palette: [UIColor] = [
        .systemPink, .systemOrange, .systemBlue, .systemTeal, .systemGreen,
        .systemPurple, .systemYellow, .systemIndigo, .systemMint, .systemRed,
    ]

    return (0..<count).map { index in
        SelectedMediaItem.preview(
            index: index,
            kind: index.isMultiple(of: 3) ? .livePhoto : .photo,
            color: palette[index % palette.count]
        )
    }
}

private extension UIImage {
    static func solidColor(_ color: UIColor, size: CGSize = CGSize(width: 240, height: 240)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
