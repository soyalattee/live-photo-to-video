//
//  DefaultVideoSaveService.swift
//  auto-photos
//
//  Created by Codex on 4/19/26.
//

import Foundation
import Photos

final class DefaultVideoSaveService: VideoSaveService {
    func saveVideo(at url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw AutoPhotosError.savePermissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard success else {
                    continuation.resume(throwing: AutoPhotosError.saveFailed)
                    return
                }

                continuation.resume(returning: ())
            }
        }
    }
}
