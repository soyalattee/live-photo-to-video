//
//  DefaultPhotoLibraryService.swift
//  auto-photos
//
//  Created by Codex on 4/19/26.
//

import Foundation
import Photos
import UIKit

final class DefaultPhotoLibraryService: PhotoLibraryService {
    private let imageManager = PHCachingImageManager()

    func resolveSelection(from assetIdentifiers: [String]) async throws -> [SelectedMediaItem] {
        let resolved = try await withThrowingTaskGroup(of: SelectedMediaItem.self) { group in
            for (index, identifier) in assetIdentifiers.enumerated() {
                group.addTask {
                    try await self.resolveSingleSelection(identifier: identifier, index: index)
                }
            }

            var items: [SelectedMediaItem] = []
            for try await item in group {
                items.append(item)
            }

            return items
        }

        return resolved.sorted { $0.selectionIndex < $1.selectionIndex }
    }

    private func resolveSingleSelection(identifier: String, index: Int) async throws -> SelectedMediaItem {
        guard let asset = fetchAsset(with: identifier) else {
            throw AutoPhotosError.assetNotFound
        }

        let thumbnail = try await requestThumbnail(for: asset)
        let kind: MediaKind
        if asset.mediaType == .video {
            kind = .video
        } else if asset.mediaSubtypes.contains(.photoLive) {
            kind = .livePhoto
        } else {
            kind = .photo
        }

        return SelectedMediaItem(
            assetLocalIdentifier: identifier,
            kind: kind,
            selectionIndex: index,
            thumbnail: thumbnail
        )
    }

    private func fetchAsset(with identifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    private func requestThumbnail(for asset: PHAsset) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            let targetSize = CGSize(width: 320, height: 320)
            self.imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else {
                    return
                }

                guard let image else {
                    continuation.resume(throwing: AutoPhotosError.imageLoadingFailed)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }
}
