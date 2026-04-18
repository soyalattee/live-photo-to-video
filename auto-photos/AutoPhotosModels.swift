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
    let assetLocalIdentifier: String
    let kind: MediaKind
    let selectionIndex: Int
    let thumbnail: UIImage

    var id: String {
        "\(assetLocalIdentifier)-\(selectionIndex)"
    }
}

struct GeneratedVideo: Equatable, Sendable {
    let url: URL
    let duration: TimeInterval
}

enum GenerationStep: String, CaseIterable, Sendable {
    case preparing
    case composing
    case exporting

    var title: String {
        switch self {
        case .preparing:
            return "불러오는 중"
        case .composing:
            return "합성 중"
        case .exporting:
            return "내보내는 중"
        }
    }

    var subtitle: String {
        switch self {
        case .preparing:
            return "선택한 사진과 Live Photo를 정리하고 있어요."
        case .composing:
            return "세로형 쇼츠 타임라인을 만들고 있어요."
        case .exporting:
            return "사진 앱에 저장할 수 있는 MP4로 내보내는 중이에요."
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

struct SelectionRules {
    static let minimumCount = 3
    static let maximumCount = 30

    static func isValid(_ count: Int) -> Bool {
        (minimumCount...maximumCount).contains(count)
    }

    static func validationMessage(for count: Int) -> String? {
        if count < minimumCount {
            return "최소 3장 선택"
        }

        if count > maximumCount {
            return "최대 30장까지 선택할 수 있어요."
        }

        return nil
    }
}

enum ResolvedClipKind: Sendable {
    case stillImage
    case liveVideo
}

struct ClipDescriptor: Equatable, Sendable {
    let kind: ResolvedClipKind
    let duration: TimeInterval
}

struct ClipDurationPolicy {
    static let photoDuration: TimeInterval = 1.6
    static let livePhotoDuration: TimeInterval = 1.6

    static func descriptor(for mediaKind: MediaKind, liveVideoAvailable: Bool) -> ClipDescriptor {
        switch mediaKind {
        case .photo:
            return ClipDescriptor(kind: .stillImage, duration: photoDuration)
        case .livePhoto:
            if liveVideoAvailable {
                return ClipDescriptor(kind: .liveVideo, duration: livePhotoDuration)
            }

            return ClipDescriptor(kind: .stillImage, duration: photoDuration)
        }
    }

    static func totalDuration(for kinds: [MediaKind]) -> TimeInterval {
        kinds.reduce(0) { partialResult, kind in
            partialResult + duration(for: kind)
        }
    }

    static func duration(for kind: MediaKind) -> TimeInterval {
        switch kind {
        case .photo:
            return photoDuration
        case .livePhoto:
            return livePhotoDuration
        }
    }
}

struct AlertInfo: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

protocol PhotoLibraryService {
    func resolveSelection(from assetIdentifiers: [String]) async throws -> [SelectedMediaItem]
}

protocol VideoGenerationService {
    func generateVideo(
        from items: [SelectedMediaItem],
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

    var errorDescription: String? {
        switch self {
        case .assetIdentifierMissing, .assetNotFound, .invalidSelection:
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
