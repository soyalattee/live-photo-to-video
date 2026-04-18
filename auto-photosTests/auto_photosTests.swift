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
    @Test("선택 개수 규칙을 검증한다")
    func selectionRulesValidation() {
        #expect(SelectionRules.validationMessage(for: 2) == "최소 3장 선택")
        #expect(SelectionRules.validationMessage(for: 3) == nil)
        #expect(SelectionRules.validationMessage(for: 30) == nil)
        #expect(SelectionRules.validationMessage(for: 31) == "최대 30장까지 선택할 수 있어요.")
    }

    @Test("사진과 Live Photo 길이 계산이 순서를 유지한다")
    func durationCalculationKeepsOrder() {
        let items = [
            makeItem(index: 0, kind: .photo),
            makeItem(index: 1, kind: .livePhoto),
            makeItem(index: 2, kind: .photo),
        ]

        #expect(items.map(\.selectionIndex) == [0, 1, 2])
        #expect(abs(ClipDurationPolicy.totalDuration(for: items.map(\.kind)) - 4.8) < 0.0001)
    }

    @Test("Live Photo 비디오가 없으면 정지 이미지 클립으로 fallback 한다")
    func livePhotoFallsBackToStillImageDescriptor() {
        let descriptor = ClipDurationPolicy.descriptor(for: .livePhoto, liveVideoAvailable: false)

        #expect(descriptor.kind == .stillImage)
        #expect(abs(descriptor.duration - 1.6) < 0.0001)
    }

    @Test("정상 생성 시 preview 상태로 전이한다")
    func generationSuccessTransitionsToPreview() async throws {
        let generator = MockVideoGenerationService(result: .success(GeneratedVideo(url: tempURL("success"), duration: 4.0)))
        let viewModel = AutoPhotosViewModel(
            photoLibraryService: MockPhotoLibraryService(),
            videoGenerationService: generator,
            videoSaveService: MockVideoSaveService()
        )

        viewModel.applyResolvedSelection(validSelection())
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
        let generator = MockVideoGenerationService(result: .cancellable)
        let viewModel = AutoPhotosViewModel(
            photoLibraryService: MockPhotoLibraryService(),
            videoGenerationService: generator,
            videoSaveService: MockVideoSaveService()
        )

        viewModel.applyResolvedSelection(validSelection())
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

    @Test("선택 해석 실패와 렌더 실패 시 error 상태를 노출한다")
    func errorTransitionsAreExposed() async throws {
        let failureGenerator = MockVideoGenerationService(result: .failure(AutoPhotosError.exportFailed))
        let viewModel = AutoPhotosViewModel(
            photoLibraryService: MockPhotoLibraryService(),
            videoGenerationService: failureGenerator,
            videoSaveService: MockVideoSaveService()
        )

        viewModel.handleSelectionResolutionFailure(AutoPhotosError.assetNotFound)
        #expect(viewModel.currentErrorMessage == "선택한 사진을 불러오지 못했어요. 다시 선택해주세요.")

        viewModel.applyResolvedSelection(validSelection())
        viewModel.startGeneration()

        #expect(await eventually {
            if case .error = viewModel.generationState {
                return true
            }

            return false
        })
    }

    @Test("저장 실패 시 preview 상태는 유지되고 alert가 표시된다")
    func saveFailureKeepsPreviewState() async throws {
        let generator = MockVideoGenerationService(result: .success(GeneratedVideo(url: tempURL("preview"), duration: 4.0)))
        let saver = MockVideoSaveService(error: AutoPhotosError.saveFailed)
        let viewModel = AutoPhotosViewModel(
            photoLibraryService: MockPhotoLibraryService(),
            videoGenerationService: generator,
            videoSaveService: saver
        )

        viewModel.applyResolvedSelection(validSelection())
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
    }

    private let result: Behavior

    init(result: Behavior) {
        self.result = result
    }

    func generateVideo(
        from items: [SelectedMediaItem],
        progress: @escaping @Sendable (GenerationStep) -> Void
    ) async throws -> GeneratedVideo {
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

private func validSelection() -> [SelectedMediaItem] {
    [
        makeItem(index: 0, kind: .photo),
        makeItem(index: 1, kind: .livePhoto),
        makeItem(index: 2, kind: .photo),
    ]
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
