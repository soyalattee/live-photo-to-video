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
            videoSaveService: saver
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
            textOverlay: TemplateTextOverlay(text: "miniLog", startTime: 1, endTime: 8),
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
}

@MainActor
private func makeViewModel(generator: MockVideoGenerationService = MockVideoGenerationService(result: .success(
    GeneratedVideo(url: tempURL("default"), duration: TemplateCatalog.templates[0].totalDuration, renderOptions: TemplateCatalog.templates[0].previewRenderOptions)
))) -> AutoPhotosViewModel {
    AutoPhotosViewModel(
        photoLibraryService: MockPhotoLibraryService(),
        videoGenerationService: generator,
        videoSaveService: MockVideoSaveService()
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

private func makeSelection(count: Int) -> [SelectedMediaItem] {
    (0..<count).map { index in
        makeItem(index: index, kind: index.isMultiple(of: 2) ? .photo : .livePhoto)
    }
}

private func makeItem(index: Int, kind: MediaKind) -> SelectedMediaItem {
    SelectedMediaItem(
        assetLocalIdentifier: "asset-\(index)",
        kind: kind,
        selectionIndex: index,
        thumbnail: solidImage()
    )
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
