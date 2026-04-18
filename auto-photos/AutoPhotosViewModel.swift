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
    @Published var generationState: GenerationState = .idle
    @Published var selectedItems: [SelectedMediaItem] = []
    @Published var alertInfo: AlertInfo?
    @Published var toastMessage: String?
    @Published var isSaving = false
    @Published var isResolvingSelection = false
    @Published var pickerResetToken = UUID()

    private let photoLibraryService: PhotoLibraryService
    private let videoGenerationService: VideoGenerationService
    private let videoSaveService: VideoSaveService

    private var recoveryDestination: ErrorRecoveryDestination = .home
    private var generationTask: Task<Void, Never>?
    private var cachedGeneratedVideo: GeneratedVideo?

    init(
        photoLibraryService: PhotoLibraryService,
        videoGenerationService: VideoGenerationService,
        videoSaveService: VideoSaveService
    ) {
        self.photoLibraryService = photoLibraryService
        self.videoGenerationService = videoGenerationService
        self.videoSaveService = videoSaveService
    }

    var validationMessage: String? {
        SelectionRules.validationMessage(for: selectedItems.count)
    }

    var selectionSummary: String {
        "\(selectedItems.count)장 선택"
    }

    var estimatedDurationText: String {
        let duration = ClipDurationPolicy.totalDuration(for: selectedItems.map(\.kind))
        return String(format: "예상 길이 %.1f초", duration)
    }

    var canGenerate: Bool {
        validationMessage == nil && !selectedItems.isEmpty && !isGenerating
    }

    var generatedVideo: GeneratedVideo? {
        if case let .preview(video) = generationState {
            return video
        }

        return cachedGeneratedVideo
    }

    var currentErrorMessage: String? {
        if case let .error(message) = generationState {
            return message
        }

        return nil
    }

    private var isGenerating: Bool {
        if case .generating = generationState {
            return true
        }

        return false
    }

    func handlePickerResults(_ results: [PHPickerResult]) async {
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
            applyResolvedSelection(resolvedItems)
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
        selectedItems = items.sorted { $0.selectionIndex < $1.selectionIndex }
        toastMessage = nil
        alertInfo = nil

        if selectedItems.isEmpty {
            generationState = .idle
        } else {
            generationState = .selectionReview
        }
    }

    func handleSelectionResolutionFailure(_ error: Error) {
        selectedItems = []
        recoveryDestination = .home
        generationState = .error(message: error.localizedDescription)
        pickerResetToken = UUID()
    }

    func startGeneration() {
        guard canGenerate else {
            alertInfo = AlertInfo(
                title: "선택 확인",
                message: validationMessage ?? "영상 생성을 시작할 수 없어요."
            )
            return
        }

        toastMessage = nil
        alertInfo = nil
        cleanupCachedVideo()

        generationTask?.cancel()
        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let video = try await videoGenerationService.generateVideo(
                    from: selectedItems,
                    progress: { [weak self] step in
                        Task { @MainActor in
                            self?.generationState = .generating(step: step)
                        }
                    }
                )

                guard !Task.isCancelled else {
                    return
                }

                cachedGeneratedVideo = video
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

    func saveGeneratedVideo() async {
        guard case let .preview(video) = generationState else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await videoSaveService.saveVideo(at: video.url)
            toastMessage = "사진 앱에 저장했어요."
        } catch {
            alertInfo = AlertInfo(title: "저장 실패", message: error.localizedDescription)
        }
    }

    func returnToSelectionReview() {
        generationState = selectedItems.isEmpty ? .idle : .selectionReview
        toastMessage = nil
    }

    func resetToHome() {
        generationTask?.cancel()
        generationTask = nil
        videoGenerationService.cancelGeneration()
        selectedItems = []
        generationState = .idle
        toastMessage = nil
        alertInfo = nil
        pickerResetToken = UUID()
        cleanupCachedVideo()
    }

    func recoverFromError() {
        switch recoveryDestination {
        case .home:
            resetToHome()
        case .selectionReview:
            generationState = selectedItems.isEmpty ? .idle : .selectionReview
        }
    }

    private func cleanupCachedVideo() {
        guard let cachedGeneratedVideo else {
            return
        }

        try? FileManager.default.removeItem(at: cachedGeneratedVideo.url)
        self.cachedGeneratedVideo = nil
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
            videoSaveService: DefaultVideoSaveService()
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
            videoSaveService: StubVideoSaveService()
        )

        switch scenario {
        case .home:
            viewModel.generationState = .idle
        case .invalidSelection:
            viewModel.applyResolvedSelection([
                SelectedMediaItem.preview(index: 0, kind: .photo, color: .systemPink),
                SelectedMediaItem.preview(index: 1, kind: .livePhoto, color: .systemOrange),
            ])
        case .generating:
            viewModel.applyResolvedSelection([
                SelectedMediaItem.preview(index: 0, kind: .photo, color: .systemPink),
                SelectedMediaItem.preview(index: 1, kind: .photo, color: .systemOrange),
                SelectedMediaItem.preview(index: 2, kind: .livePhoto, color: .systemBlue),
            ])
            viewModel.generationState = .generating(step: .composing)
        case .preview:
            viewModel.applyResolvedSelection([
                SelectedMediaItem.preview(index: 0, kind: .photo, color: .systemPink),
                SelectedMediaItem.preview(index: 1, kind: .photo, color: .systemOrange),
                SelectedMediaItem.preview(index: 2, kind: .livePhoto, color: .systemBlue),
            ])
            let previewURL = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-preview.mp4")
            viewModel.generationState = .preview(GeneratedVideo(url: previewURL, duration: 4.0))
        case .error:
            viewModel.applyResolvedSelection([
                SelectedMediaItem.preview(index: 0, kind: .photo, color: .systemPink),
                SelectedMediaItem.preview(index: 1, kind: .photo, color: .systemOrange),
                SelectedMediaItem.preview(index: 2, kind: .livePhoto, color: .systemBlue),
            ])
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

private final class StubVideoGenerationService: VideoGenerationService {
    func generateVideo(
        from items: [SelectedMediaItem],
        progress: @escaping @Sendable (GenerationStep) -> Void
    ) async throws -> GeneratedVideo {
        progress(.preparing)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stub-preview.mp4")
        return GeneratedVideo(url: url, duration: 3.0)
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

private extension UIImage {
    static func solidColor(_ color: UIColor, size: CGSize = CGSize(width: 240, height: 240)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
