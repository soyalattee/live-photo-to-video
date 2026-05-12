//
//  AutoPhotosModels.swift
//  auto-photos
//
//  Created by Codex on 4/19/26.
//

import Foundation
import SwiftUI
import UIKit

enum MediaKind: String, CaseIterable, Sendable {
    case photo
    case livePhoto
}

struct SelectedMediaItem: Identifiable {
    let id: UUID
    let assetLocalIdentifier: String
    let kind: MediaKind
    var selectionIndex: Int
    let thumbnail: UIImage

    init(
        id: UUID = UUID(),
        assetLocalIdentifier: String,
        kind: MediaKind,
        selectionIndex: Int,
        thumbnail: UIImage
    ) {
        self.id = id
        self.assetLocalIdentifier = assetLocalIdentifier
        self.kind = kind
        self.selectionIndex = selectionIndex
        self.thumbnail = thumbnail
    }
}

struct VideoRenderOptions: Equatable, Hashable, Sendable {
    var includesMusic: Bool
    var includesText: Bool

    static let none = VideoRenderOptions(includesMusic: false, includesText: false)
}

struct GeneratedVideo: Equatable, Sendable {
    let url: URL
    let duration: TimeInterval
    let renderOptions: VideoRenderOptions
}

enum GenerationStep: String, CaseIterable, Sendable {
    case preparing
    case composing
    case exporting

    var title: String {
        switch self {
        case .preparing:
            return "소스를 정리하는 중"
        case .composing:
            return "템플릿 컷을 배치하는 중"
        case .exporting:
            return "최종 영상을 굽는 중"
        }
    }

    var subtitle: String {
        switch self {
        case .preparing:
            return "선택한 사진과 Live Photo를 템플릿 순서에 맞게 준비하고 있어요."
        case .composing:
            return "각 장면 길이와 비율을 맞춰 세로형 타임라인을 만들고 있어요."
        case .exporting:
            return "미리보기와 저장에 사용할 MP4를 내보내는 중이에요."
        }
    }
}

enum GenerationState: Equatable, Sendable {
    case idle
    case selectionReview
    case generating(step: GenerationStep)
    case preview(GeneratedVideo)
    case error(message: String)
}

enum ErrorRecoveryDestination: Sendable {
    case home
    case selectionReview
}

enum SelectionRules {
    static let librarySelectionUpperBound = 30

    static func pickerLimit(for template: VideoTemplate?) -> Int {
        guard let template else {
            return librarySelectionUpperBound
        }

        if template.usesSelectionCount {
            if let maximumSelectionCount = template.maximumSelectionCount {
                return min(maximumSelectionCount, librarySelectionUpperBound)
            }

            return 0
        }

        return min(template.photoCount, librarySelectionUpperBound)
    }
}

struct VideoGenerationRequest: Sendable {
    let items: [SelectedMediaItem]
    let template: VideoTemplate
    let renderOptions: VideoRenderOptions
}

struct AlertInfo: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

struct ShareSheetPayload: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL
}

protocol PhotoLibraryService {
    func resolveSelection(from assetIdentifiers: [String]) async throws -> [SelectedMediaItem]
}

protocol VideoGenerationService {
    func generateVideo(
        from request: VideoGenerationRequest,
        progress: @escaping @Sendable (GenerationStep) -> Void
    ) async throws -> GeneratedVideo

    func cancelGeneration()
}

protocol VideoSaveService {
    func saveVideo(at url: URL) async throws
}

enum AutoPhotosError: LocalizedError, Equatable {
    case assetIdentifierMissing
    case assetNotFound
    case imageLoadingFailed
    case livePhotoVideoNotFound
    case exportFailed
    case savePermissionDenied
    case saveFailed
    case invalidSelection
    case templateMissing
    case templateConfigurationInvalid

    var errorDescription: String? {
        switch self {
        case .assetIdentifierMissing, .assetNotFound:
            return "선택한 사진을 불러오지 못했어요. 다시 선택해주세요."
        case .imageLoadingFailed:
            return "사진을 불러오는 중 문제가 생겼어요."
        case .livePhotoVideoNotFound:
            return "Live Photo 영상을 찾지 못했어요."
        case .exportFailed:
            return "영상 생성에 실패했어요. 다시 시도해주세요."
        case .savePermissionDenied:
            return "사진 앱에 저장하려면 저장 권한이 필요해요."
        case .saveFailed:
            return "저장에 실패했어요. 저장 공간과 권한을 확인해주세요."
        case .invalidSelection:
            return "템플릿에 맞는 개수로 사진을 다시 선택해주세요."
        case .templateMissing:
            return "먼저 템플릿을 선택해주세요."
        case .templateConfigurationInvalid:
            return "템플릿 설정에 문제가 있어요. 템플릿 정보를 확인해주세요."
        }
    }
}

enum UITestScenario: String {
    case home
    case invalidSelection
    case generating
    case preview
    case error
}
