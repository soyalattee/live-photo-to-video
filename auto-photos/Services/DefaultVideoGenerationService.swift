//
//  DefaultVideoGenerationService.swift
//  auto-photos
//
//  Created by Codex on 4/19/26.
//

import AVFoundation
import CoreVideo
import Foundation
import Photos
import UIKit

private struct PreparedClip {
    let url: URL
    let duration: CMTime
}

final class DefaultVideoGenerationService: VideoGenerationService {
    private let imageManager = PHImageManager.default()
    private let renderSize = CGSize(width: 1080, height: 1920)
    private let framesPerSecond: Int32 = 30
    private let exportSessionQueue = DispatchQueue(label: "auto-photos.export-session")

    private var activeExportSession: AVAssetExportSession?

    func generateVideo(
        from items: [SelectedMediaItem],
        progress: @escaping @Sendable (GenerationStep) -> Void
    ) async throws -> GeneratedVideo {
        guard SelectionRules.isValid(items.count) else {
            throw AutoPhotosError.invalidSelection
        }

        var temporaryURLs: [URL] = []

        do {
            progress(.preparing)
            let preparedClips = try await prepareClips(from: items)
            temporaryURLs.append(contentsOf: preparedClips.map(\.url))

            try Task.checkCancellation()

            progress(.composing)
            let composition = try await composeVideo(from: preparedClips)

            try Task.checkCancellation()

            progress(.exporting)
            let finalURL = makeTemporaryURL(prefix: "auto-photos-final", pathExtension: "mp4")
            try await export(asset: composition, videoComposition: nil, to: finalURL)

            cleanup(urls: temporaryURLs)

            return GeneratedVideo(url: finalURL, duration: composition.duration.seconds)
        } catch {
            cleanup(urls: temporaryURLs)
            throw error
        }
    }

    func cancelGeneration() {
        exportSessionQueue.sync {
            activeExportSession?.cancelExport()
        }
    }

    private func prepareClips(from items: [SelectedMediaItem]) async throws -> [PreparedClip] {
        var clips: [PreparedClip] = []

        for item in items.sorted(by: { $0.selectionIndex < $1.selectionIndex }) {
            try Task.checkCancellation()
            clips.append(try await makeClip(for: item))
        }

        return clips
    }

    private func makeClip(for item: SelectedMediaItem) async throws -> PreparedClip {
        switch item.kind {
        case .photo:
            return try await makeStillClip(from: item.assetLocalIdentifier, duration: ClipDurationPolicy.photoDuration)
        case .livePhoto:
            if let pairedVideoURL = try await exportPairedVideoURL(for: item.assetLocalIdentifier) {
                defer { try? FileManager.default.removeItem(at: pairedVideoURL) }

                do {
                    return try await makeNormalizedLiveClip(from: pairedVideoURL)
                } catch {
                    return try await makeStillClip(from: item.assetLocalIdentifier, duration: ClipDurationPolicy.photoDuration)
                }
            }

            return try await makeStillClip(from: item.assetLocalIdentifier, duration: ClipDurationPolicy.photoDuration)
        }
    }

    private func makeStillClip(from assetIdentifier: String, duration: TimeInterval) async throws -> PreparedClip {
        let image = try await requestOriginalImage(for: assetIdentifier)
        let renderedImage = image.aspectFilled(to: renderSize)
        let outputURL = makeTemporaryURL(prefix: "auto-photos-photo", pathExtension: "mp4")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(renderSize.width),
            AVVideoHeightKey: Int(renderSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoExpectedSourceFrameRateKey: framesPerSecond,
            ],
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourceBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(renderSize.width),
            kCVPixelBufferHeightKey as String: Int(renderSize.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )

        guard writer.canAdd(writerInput) else {
            throw AutoPhotosError.exportFailed
        }

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = max(Int(duration * Double(framesPerSecond)), 1)

        for frameIndex in 0..<totalFrames {
            try Task.checkCancellation()

            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }

            guard
                let pool = adaptor.pixelBufferPool,
                let buffer = Self.makePixelBuffer(from: renderedImage, size: renderSize, pool: pool)
            else {
                throw AutoPhotosError.exportFailed
            }

            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: framesPerSecond)
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? AutoPhotosError.exportFailed
            }
        }

        writerInput.markAsFinished()
        try await writer.finishWritingChecked()

        let durationTime = CMTime(value: CMTimeValue(totalFrames), timescale: framesPerSecond)
        return PreparedClip(url: outputURL, duration: durationTime)
    }

    private func makeNormalizedLiveClip(from sourceURL: URL) async throws -> PreparedClip {
        let asset = AVURLAsset(url: sourceURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let sourceTrack = tracks.first else {
            throw AutoPhotosError.livePhotoVideoNotFound
        }

        let sourceDuration = try await asset.load(.duration)
        let clipDuration = min(sourceDuration, CMTime(seconds: ClipDurationPolicy.livePhotoDuration, preferredTimescale: framesPerSecond))

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AutoPhotosError.exportFailed
        }

        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: clipDuration),
            of: sourceTrack,
            at: .zero
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: framesPerSecond)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: clipDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        let transform = try await makeAspectFillTransform(for: sourceTrack, renderSize: renderSize)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let outputURL = makeTemporaryURL(prefix: "auto-photos-live", pathExtension: "mp4")
        try await export(asset: composition, videoComposition: videoComposition, to: outputURL)

        return PreparedClip(url: outputURL, duration: clipDuration)
    }

    private func composeVideo(from clips: [PreparedClip]) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AutoPhotosError.exportFailed
        }

        var insertTime = CMTime.zero

        for clip in clips {
            let asset = AVURLAsset(url: clip.url)
            let tracks = try await asset.loadTracks(withMediaType: .video)

            guard let track = tracks.first else {
                throw AutoPhotosError.exportFailed
            }

            let clipDuration = try await asset.load(.duration)
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: clipDuration),
                of: track,
                at: insertTime
            )

            insertTime = CMTimeAdd(insertTime, clipDuration)
        }

        return composition
    }

    private func export(asset: AVAsset, videoComposition: AVVideoComposition?, to outputURL: URL) async throws {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw AutoPhotosError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition

        setActiveExportSession(exportSession)
        defer { clearActiveExportSession(exportSession) }

        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? AutoPhotosError.exportFailed)
                default:
                    continuation.resume(throwing: AutoPhotosError.exportFailed)
                }
            }
        }
    }

    private func requestOriginalImage(for identifier: String) async throws -> UIImage {
        guard let asset = fetchAsset(with: identifier) else {
            throw AutoPhotosError.assetNotFound
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .current
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(throwing: AutoPhotosError.imageLoadingFailed)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func exportPairedVideoURL(for identifier: String) async throws -> URL? {
        guard let asset = fetchAsset(with: identifier) else {
            throw AutoPhotosError.assetNotFound
        }

        guard let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .pairedVideo }) else {
            return nil
        }

        let outputURL = makeTemporaryURL(prefix: "auto-photos-paired", pathExtension: resource.originalFilename.pathExtensionOrDefault)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHAssetResourceManager.default().writeData(for: resource, toFile: outputURL, options: options) { error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume(returning: ())
                }
            }

            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }
    }

    private func fetchAsset(with identifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    private func makeAspectFillTransform(for track: AVAssetTrack, renderSize: CGSize) async throws -> CGAffineTransform {
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)

        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform).standardized
        let translatedTransform = preferredTransform.concatenating(
            CGAffineTransform(translationX: -transformedRect.origin.x, y: -transformedRect.origin.y)
        )

        let scale = max(
            renderSize.width / transformedRect.width,
            renderSize.height / transformedRect.height
        )

        let scaledSize = CGSize(width: transformedRect.width * scale, height: transformedRect.height * scale)
        let centeringTransform = CGAffineTransform(
            translationX: (renderSize.width - scaledSize.width) / 2,
            y: (renderSize.height - scaledSize.height) / 2
        )

        return translatedTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(centeringTransform)
    }

    private func setActiveExportSession(_ session: AVAssetExportSession) {
        exportSessionQueue.sync {
            activeExportSession = session
        }
    }

    private func clearActiveExportSession(_ session: AVAssetExportSession) {
        exportSessionQueue.sync {
            if activeExportSession === session {
                activeExportSession = nil
            }
        }
    }

    private func makeTemporaryURL(prefix: String, pathExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private func cleanup(urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func makePixelBuffer(from image: UIImage, size: CGSize, pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)

        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard
            let cgImage = image.cgImage,
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(pixelBuffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
        else {
            return nil
        }

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return pixelBuffer
    }
}

private extension UIImage {
    func aspectFilled(to renderSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: renderSize, format: format).image { _ in
            let horizontalScale = renderSize.width / size.width
            let verticalScale = renderSize.height / size.height
            let scale = max(horizontalScale, verticalScale)
            let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
            let origin = CGPoint(
                x: (renderSize.width - scaledSize.width) / 2,
                y: (renderSize.height - scaledSize.height) / 2
            )

            draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}

private extension AVAssetWriter {
    func finishWritingChecked() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            finishWriting {
                if let error = self.error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: ())
            }
        }
    }
}

private extension String {
    var pathExtensionOrDefault: String {
        let ext = (self as NSString).pathExtension
        return ext.isEmpty ? "mov" : ext
    }
}
