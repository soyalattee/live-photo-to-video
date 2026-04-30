//
//  DefaultVideoGenerationService.swift
//  auto-photos
//
//  Created by Codex on 4/19/26.
//

@preconcurrency import AVFoundation
import CoreVideo
import Foundation
import ImageIO
import Photos
import QuartzCore
import UIKit

private struct PreparedClip {
    let url: URL
    let duration: CMTime
}

private struct AssetPhotoRepresentation {
    let image: UIImage
    let orientation: UIImage.Orientation

    var normalizedImage: UIImage {
        image.normalized()
    }

    var isMirrored: Bool {
        orientation.isMirrored
    }
}

final class DefaultVideoGenerationService: VideoGenerationService {
    private let imageManager = PHImageManager.default()
    private let renderSize = CGSize(width: 1080, height: 1920)
    private let framesPerSecond: Int32 = 30
    private let exportSessionQueue = DispatchQueue(label: "auto-photos.export-session")

    private var activeExportSession: AVAssetExportSession?

    func generateVideo(
        from request: VideoGenerationRequest,
        progress: @escaping @Sendable (GenerationStep) -> Void
    ) async throws -> GeneratedVideo {
        guard request.items.count == request.template.photoCount else {
            throw AutoPhotosError.invalidSelection
        }

        guard request.template.photoCount == request.template.clipDurations.count else {
            throw AutoPhotosError.templateConfigurationInvalid
        }

        var temporaryURLs: [URL] = []

        do {
            progress(.preparing)
            let preparedClips = try await prepareClips(
                from: request.items,
                clipDurations: request.template.clipDurations
            )
            temporaryURLs.append(contentsOf: preparedClips.map(\.url))

            try Task.checkCancellation()

            progress(.composing)
            let composition = try await composeVideo(from: preparedClips)
            try await attachAudioIfNeeded(to: composition, request: request)
            let videoComposition = makeVideoCompositionIfNeeded(for: composition, request: request)

            try Task.checkCancellation()

            progress(.exporting)
            let finalURL = makeTemporaryURL(prefix: "auto-photos-final", pathExtension: "mp4")
            try await export(asset: composition, videoComposition: videoComposition, to: finalURL)

            cleanup(urls: temporaryURLs)

            return GeneratedVideo(
                url: finalURL,
                duration: composition.duration.seconds,
                renderOptions: request.renderOptions
            )
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

    private func prepareClips(
        from items: [SelectedMediaItem],
        clipDurations: [TimeInterval]
    ) async throws -> [PreparedClip] {
        var clips: [PreparedClip] = []
        let sortedItems = items.sorted(by: { $0.selectionIndex < $1.selectionIndex })

        for (item, duration) in zip(sortedItems, clipDurations) {
            try Task.checkCancellation()
            clips.append(try await makeClip(for: item, duration: duration))
        }

        return clips
    }

    private func makeClip(for item: SelectedMediaItem, duration: TimeInterval) async throws -> PreparedClip {
        switch item.kind {
        case .photo:
            let photoRepresentation = try await requestPhotoRepresentation(for: item.assetLocalIdentifier)
            return try await makeStillClip(from: photoRepresentation, duration: duration)
        case .livePhoto:
            let photoRepresentation = try await requestPhotoRepresentation(for: item.assetLocalIdentifier)

            if let pairedVideoURL = try await exportPairedVideoURL(for: item.assetLocalIdentifier) {
                defer { try? FileManager.default.removeItem(at: pairedVideoURL) }

                do {
                    return try await makeNormalizedLiveClip(
                        from: pairedVideoURL,
                        duration: duration,
                        mirrorHorizontally: photoRepresentation.isMirrored
                    )
                } catch {
                    return try await makeStillClip(from: photoRepresentation, duration: duration)
                }
            }

            return try await makeStillClip(from: photoRepresentation, duration: duration)
        }
    }

    private func makeStillClip(
        from photoRepresentation: AssetPhotoRepresentation,
        duration: TimeInterval
    ) async throws -> PreparedClip {
        let renderedImage = photoRepresentation.normalizedImage.aspectFilled(to: renderSize)
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

    private func makeNormalizedLiveClip(
        from sourceURL: URL,
        duration: TimeInterval,
        mirrorHorizontally: Bool
    ) async throws -> PreparedClip {
        let asset = AVURLAsset(url: sourceURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let sourceTrack = tracks.first else {
            throw AutoPhotosError.livePhotoVideoNotFound
        }

        let sourceDuration = try await asset.load(.duration)
        let requestedDuration = CMTime(seconds: duration, preferredTimescale: framesPerSecond)
        let clipDuration = min(sourceDuration, requestedDuration)

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
        let transform = try await makeAspectFillTransform(
            for: sourceTrack,
            renderSize: renderSize,
            mirrorHorizontally: mirrorHorizontally
        )
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

    private func attachAudioIfNeeded(
        to composition: AVMutableComposition,
        request: VideoGenerationRequest
    ) async throws {
        guard request.renderOptions.includesMusic else {
            return
        }

        guard let audioURL = request.template.audioTrack?.assetURL else {
            return
        }

        let audioAsset = AVURLAsset(url: audioURL)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)

        guard let sourceTrack = audioTracks.first else {
            return
        }

        let sourceDuration = try await audioAsset.load(.duration)
        guard sourceDuration.isNumeric && sourceDuration.seconds > 0 else {
            return
        }

        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AutoPhotosError.exportFailed
        }

        let targetDuration = composition.duration
        var cursor = CMTime.zero

        while CMTimeCompare(cursor, targetDuration) < 0 {
            let remaining = CMTimeSubtract(targetDuration, cursor)
            let segmentDuration = CMTimeCompare(remaining, sourceDuration) < 0 ? remaining : sourceDuration
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: segmentDuration),
                of: sourceTrack,
                at: cursor
            )
            cursor = CMTimeAdd(cursor, segmentDuration)
        }
    }

    private func makeVideoCompositionIfNeeded(
        for composition: AVMutableComposition,
        request: VideoGenerationRequest
    ) -> AVMutableVideoComposition? {
        guard request.renderOptions.includesText else {
            return nil
        }

        guard
            let overlay = request.template.textOverlay,
            overlay.endTime > overlay.startTime,
            let videoTrack = composition.tracks(withMediaType: .video).first
        else {
            return nil
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: framesPerSecond)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)

        let textSize = CGSize(width: renderSize.width * 0.82, height: 132)
        let textOrigin = CGPoint(
            x: (renderSize.width * overlay.position.normalizedX) - (textSize.width / 2),
            y: (renderSize.height * overlay.position.normalizedY) - (textSize.height / 2)
        )

        let textFrame = CGRect(
            x: min(max(textOrigin.x, 48), renderSize.width - textSize.width - 48),
            y: min(max(textOrigin.y, 48), renderSize.height - textSize.height - 48),
            width: textSize.width,
            height: textSize.height
        )

        let resolvedFont = UIFont(name: overlay.fontName, size: overlay.fontSize)
            ?? UIFont.boldSystemFont(ofSize: overlay.fontSize)
        let textLayer = CALayer()
        textLayer.frame = textFrame
        textLayer.contentsGravity = .resizeAspect
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.opacity = 0
        textLayer.contents = makeOverlayTextImage(
            text: overlay.text,
            font: resolvedFont,
            size: textFrame.size
        )?.cgImage
        parentLayer.addSublayer(textLayer)

        let totalDuration = max(composition.duration.seconds, 0.01)
        let startProgress = max(0, min(overlay.startTime / totalDuration, 1))
        let endProgress = max(startProgress, min(overlay.endTime / totalDuration, 1))
        let enterProgress = min(startProgress + 0.03, endProgress)
        let exitProgress = max(startProgress, endProgress - 0.03)

        let opacityAnimation = makeOverlayOpacityAnimation(
            totalDuration: totalDuration,
            startProgress: startProgress,
            enterProgress: enterProgress,
            exitProgress: exitProgress,
            endProgress: endProgress
        )
        textLayer.add(opacityAnimation, forKey: "templateTextOpacity")

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        return videoComposition
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

    private func requestPhotoRepresentation(for identifier: String) async throws -> AssetPhotoRepresentation {
        guard let asset = fetchAsset(with: identifier) else {
            throw AutoPhotosError.assetNotFound
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .current
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, cgOrientation, info in
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

                let orientation = UIImage.Orientation(cgOrientation)
                let resolvedImage: UIImage

                if let cgImage = image.cgImage {
                    resolvedImage = UIImage(
                        cgImage: cgImage,
                        scale: image.scale,
                        orientation: orientation
                    )
                } else {
                    resolvedImage = image
                }

                continuation.resume(
                    returning: AssetPhotoRepresentation(
                        image: resolvedImage,
                        orientation: orientation
                    )
                )
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

    private func makeAspectFillTransform(
        for track: AVAssetTrack,
        renderSize: CGSize,
        mirrorHorizontally: Bool
    ) async throws -> CGAffineTransform {
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

        var finalTransform = translatedTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(centeringTransform)

        if mirrorHorizontally {
            finalTransform = finalTransform.concatenating(
                CGAffineTransform(translationX: renderSize.width, y: 0)
                    .scaledBy(x: -1, y: 1)
            )
        }

        return finalTransform
    }

    private func setActiveExportSession(_ session: AVAssetExportSession) {
        exportSessionQueue.sync {
            activeExportSession = session
        }
    }

    private func makeOverlayOpacityAnimation(
        totalDuration: TimeInterval,
        startProgress: Double,
        enterProgress: Double,
        exitProgress: Double,
        endProgress: Double
    ) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0, 0, 1, 1, 0, 0]
        animation.keyTimes = [
            0,
            NSNumber(value: startProgress),
            NSNumber(value: enterProgress),
            NSNumber(value: exitProgress),
            NSNumber(value: endProgress),
            1,
        ]
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.duration = totalDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    private func makeOverlayTextImage(
        text: String,
        font: UIFont,
        size: CGSize
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle,
        ]

        let attributedText = NSAttributedString(string: text, attributes: attributes)

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let insetBounds = CGRect(origin: .zero, size: size).insetBy(dx: 20, dy: 12)
            let measuredRect = attributedText.boundingRect(
                with: insetBounds.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let drawRect = CGRect(
                x: insetBounds.minX,
                y: insetBounds.minY + max((insetBounds.height - measuredRect.height) / 2, 0),
                width: insetBounds.width,
                height: min(measuredRect.height, insetBounds.height)
            )
            attributedText.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
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
    func normalized() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

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

private extension UIImage.Orientation {
    init(_ orientation: CGImagePropertyOrientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }

    var isMirrored: Bool {
        switch self {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            return true
        default:
            return false
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
