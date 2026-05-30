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

private final class SendableExportSessionReference: @unchecked Sendable {
    let session: AVAssetExportSession

    init(session: AVAssetExportSession) {
        self.session = session
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
        let resolvedPhotoCount = request.template.resolvedPhotoCount(for: request.items.count)
        let clipDurations = request.template.resolvedClipDurations(for: request.items.count)

        guard request.items.count == resolvedPhotoCount else {
            throw AutoPhotosError.invalidSelection
        }

        guard resolvedPhotoCount == clipDurations.count else {
            throw AutoPhotosError.templateConfigurationInvalid
        }

        var temporaryURLs: [URL] = []

        do {
            progress(.preparing)
            let preparedClips = try await prepareClips(
                from: request.items,
                clipDurations: clipDurations,
                template: request.template
            )
            temporaryURLs.append(contentsOf: preparedClips.map(\.url))

            try Task.checkCancellation()

            progress(.composing)
            let composition = try await composeVideo(from: preparedClips)
            let audioMix = try await attachAudioIfNeeded(to: composition, request: request)
            let videoComposition = makeVideoCompositionIfNeeded(for: composition, request: request)

            try Task.checkCancellation()

            progress(.exporting)
            let finalURL = makeTemporaryURL(prefix: "auto-photos-final", pathExtension: "mp4")
            try await export(
                asset: composition,
                videoComposition: videoComposition,
                audioMix: audioMix,
                to: finalURL
            )

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
        clipDurations: [TimeInterval],
        template: VideoTemplate
    ) async throws -> [PreparedClip] {
        var clips: [PreparedClip] = []
        let sortedItems = items.sorted(by: { $0.selectionIndex < $1.selectionIndex })

        for (clipIndex, pair) in zip(sortedItems, clipDurations).enumerated() {
            try Task.checkCancellation()
            let (item, duration) = pair
            clips.append(
                try await makeClip(
                    for: item,
                    duration: duration,
                    clipIndex: clipIndex,
                    template: template
                )
            )
        }

        return clips
    }

    private func makeClip(
        for item: SelectedMediaItem,
        duration: TimeInterval,
        clipIndex: Int,
        template: VideoTemplate
    ) async throws -> PreparedClip {
        switch item.kind {
        case .photo:
            let photoRepresentation = try await requestPhotoRepresentation(for: item.assetLocalIdentifier)
            return try await makeStillClip(from: photoRepresentation, duration: duration)
        case .livePhoto:
            let photoRepresentation = try await requestPhotoRepresentation(for: item.assetLocalIdentifier)
            let clipMediaMode = template.clipMediaMode(for: clipIndex)

            guard clipMediaMode != .stillImage else {
                return try await makeStillClip(from: photoRepresentation, duration: duration)
            }

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
        case .video:
            let sourceVideoURL = try await exportVideoURL(for: item.assetLocalIdentifier)
            defer { try? FileManager.default.removeItem(at: sourceVideoURL) }

            return try await makeNormalizedMotionClip(
                from: sourceVideoURL,
                duration: duration,
                mirrorHorizontally: false,
                missingVideoError: .videoAssetNotFound
            )
        }
    }

    private func makeStillClip(
        from photoRepresentation: AssetPhotoRepresentation,
        duration: TimeInterval
    ) async throws -> PreparedClip {
        let renderedImage = photoRepresentation.normalizedImage
            .aspectFilled(to: renderSize)
            .flippedVertically()
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
        try await makeNormalizedMotionClip(
            from: sourceURL,
            duration: duration,
            mirrorHorizontally: mirrorHorizontally,
            missingVideoError: .livePhotoVideoNotFound
        )
    }

    private func makeNormalizedMotionClip(
        from sourceURL: URL,
        duration: TimeInterval,
        mirrorHorizontally: Bool,
        missingVideoError: AutoPhotosError
    ) async throws -> PreparedClip {
        let asset = AVURLAsset(url: sourceURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let sourceTrack = tracks.first else {
            throw missingVideoError
        }

        let sourceDuration = try await asset.load(.duration)
        let requestedDuration = CMTime(seconds: duration, preferredTimescale: framesPerSecond)

        guard
            sourceDuration.isNumeric,
            requestedDuration.isNumeric,
            sourceDuration.seconds > 0,
            requestedDuration.seconds > 0
        else {
            throw missingVideoError
        }

        let sourceClipDuration = CMTimeCompare(sourceDuration, requestedDuration) < 0 ? sourceDuration : requestedDuration
        let sourceStartTime = CMTimeCompare(sourceDuration, sourceClipDuration) > 0
            ? CMTimeMultiplyByFloat64(CMTimeSubtract(sourceDuration, sourceClipDuration), multiplier: 0.5)
            : .zero
        var outputDuration = sourceClipDuration

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AutoPhotosError.exportFailed
        }

        try compositionTrack.insertTimeRange(
            CMTimeRange(start: sourceStartTime, duration: sourceClipDuration),
            of: sourceTrack,
            at: .zero
        )

        if CMTimeCompare(sourceClipDuration, requestedDuration) < 0 {
            compositionTrack.scaleTimeRange(
                CMTimeRange(start: .zero, duration: sourceClipDuration),
                toDuration: requestedDuration
            )
            outputDuration = requestedDuration
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: framesPerSecond)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: outputDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        let transform = try await makeAspectFillTransform(
            for: sourceTrack,
            renderSize: renderSize,
            mirrorHorizontally: mirrorHorizontally
        )
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let outputURL = makeTemporaryURL(prefix: "auto-photos-motion", pathExtension: "mp4")
        try await export(asset: composition, videoComposition: videoComposition, to: outputURL)

        return PreparedClip(url: outputURL, duration: outputDuration)
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
    ) async throws -> AVAudioMix? {
        guard request.renderOptions.includesMusic else {
            return nil
        }

        guard let audioURL = request.template.audioTrack?.assetURL else {
            return nil
        }

        let audioAsset = AVURLAsset(url: audioURL)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)

        guard let sourceTrack = audioTracks.first else {
            return nil
        }

        let sourceDuration = try await audioAsset.load(.duration)
        guard sourceDuration.isNumeric && sourceDuration.seconds > 0 else {
            return nil
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

        return makeFadeOutAudioMix(for: compositionTrack, targetDuration: targetDuration)
    }

    private func makeVideoCompositionIfNeeded(
        for composition: AVMutableComposition,
        request: VideoGenerationRequest
    ) -> AVMutableVideoComposition? {
        let shouldRenderBasicText: Bool
        if request.renderOptions.includesText, let overlay = request.template.textOverlay {
            shouldRenderBasicText = overlay.endTime > overlay.startTime
        } else {
            shouldRenderBasicText = false
        }
        let introEffect = request.template.resolvedCinematicIntro(
            customization: request.cinematicTextCustomization
        )
        let frameOverlay = request.template.frameOverlay
        let lockScreenOverlay = request.renderOptions.includesText ? request.template.lockScreenOverlay : nil
        let hasWatermark = request.renderOptions.appliesWatermark

        guard
            shouldRenderBasicText || introEffect != nil || frameOverlay != nil || lockScreenOverlay != nil || hasWatermark,
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

        let totalDuration = max(composition.duration.seconds, 0.01)

        if let introEffect {
            addCinematicIntroLayers(
                to: parentLayer,
                effect: introEffect,
                totalDuration: totalDuration,
                includesText: request.renderOptions.includesText
            )
        }

        if let frameOverlay {
            addFrameOverlay(
                to: parentLayer,
                overlay: frameOverlay,
                totalDuration: totalDuration
            )
        }

        if let lockScreenOverlay {
            addLockScreenLogOverlay(
                to: parentLayer,
                overlay: lockScreenOverlay,
                items: request.items,
                clipDurations: request.template.resolvedClipDurations(for: request.items.count),
                totalDuration: totalDuration,
                customization: request.cinematicTextCustomization
            )
        }

        if shouldRenderBasicText, let overlay = request.template.textOverlay {
            addBasicTextOverlay(
                to: parentLayer,
                overlay: overlay,
                totalDuration: totalDuration
            )
        }

        addWatermarkLayer(to: parentLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        return videoComposition
    }

    private func addFrameOverlay(
        to parentLayer: CALayer,
        overlay: TemplateFrameOverlay,
        totalDuration: TimeInterval
    ) {
        guard
            let assetURL = overlay.imageAsset.assetURL,
            let image = UIImage(contentsOfFile: assetURL.path),
            let cgImage = image.cgImage
        else {
            return
        }

        let frameLayer = CALayer()
        frameLayer.frame = CGRect(origin: .zero, size: renderSize)
        frameLayer.contents = cgImage
        frameLayer.contentsGravity = .resize
        frameLayer.contentsScale = UIScreen.main.scale
        frameLayer.opacity = 0
        parentLayer.addSublayer(frameLayer)

        let startProgress = max(0, min(overlay.startTime / totalDuration, 1))
        let resolvedEndTime = overlay.endTime.map { min(max($0, overlay.startTime), totalDuration) } ?? totalDuration
        let endProgress = max(startProgress, min(resolvedEndTime / totalDuration, 1))
        let enterProgress = min(startProgress + 0.01, endProgress)
        let exitProgress = endProgress

        let opacityAnimation = makeOverlayOpacityAnimation(
            totalDuration: totalDuration,
            startProgress: startProgress,
            enterProgress: enterProgress,
            exitProgress: exitProgress,
            endProgress: endProgress
        )
        opacityAnimation.values = [0, 0, 1, 1, 1, 1]
        frameLayer.add(opacityAnimation, forKey: "frameOverlayOpacity")
    }

    private func addBasicTextOverlay(
        to parentLayer: CALayer,
        overlay: TemplateTextOverlay,
        totalDuration: TimeInterval
    ) {
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

        let resolvedFont = AppFontCatalog.uiKitFont(
            overlay.fontName,
            size: CGFloat(overlay.fontSize),
            fallbackWeight: .bold
        )
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
    }

    private func addWatermarkLayer(to parentLayer: CALayer) {
        guard
            let url = Bundle.main.url(forResource: "wartermark", withExtension: "png"),
            let image = UIImage(contentsOfFile: url.path),
            let cgImage = image.cgImage
        else { return }

        let size: CGFloat = 260
        let margin: CGFloat = 56

        let watermarkLayer = CALayer()
        watermarkLayer.frame = CGRect(
            x: renderSize.width - margin - size,
            y: margin,
            width: size,
            height: size
        )
        watermarkLayer.contents = cgImage
        watermarkLayer.contentsGravity = .resizeAspect
        watermarkLayer.contentsScale = UIScreen.main.scale
        watermarkLayer.opacity = 0.42
        parentLayer.addSublayer(watermarkLayer)
    }

    private func addLockScreenLogOverlay(
        to parentLayer: CALayer,
        overlay: TemplateLockScreenOverlay,
        items: [SelectedMediaItem],
        clipDurations: [TimeInterval],
        totalDuration: TimeInterval,
        customization: TemplateCinematicTextCustomization?
    ) {
        let sortedItems = items.sorted { $0.selectionIndex < $1.selectionIndex }
        let bottomText = normalizedText(
            customization?.secondaryText,
            fallback: overlay.defaultBottomText
        )
        var clipStart: TimeInterval = 0

        addLockScreenControl(
            to: parentLayer,
            systemImageName: "camera.fill",
            fallbackSystemImageName: "camera",
            center: CGPoint(
                x: renderSize.width * 0.18,
                y: TemplateLockScreenOverlay.videoLayerY(
                    fromTopLeftCenterY: renderSize.height * 0.915,
                    renderHeight: renderSize.height
                )
            )
        )
        addLockScreenControl(
            to: parentLayer,
            systemImageName: "flashlight.on.fill",
            fallbackSystemImageName: "flashlight.off.fill",
            center: CGPoint(
                x: renderSize.width * 0.82,
                y: TemplateLockScreenOverlay.videoLayerY(
                    fromTopLeftCenterY: renderSize.height * 0.915,
                    renderHeight: renderSize.height
                )
            )
        )

        for (clipIndex, pair) in zip(sortedItems, clipDurations).enumerated() {
            let (item, clipDuration) = pair
            let clipEnd = min(clipStart + clipDuration, totalDuration)
            let date = item.creationDate ?? Date()
            let isFirstClip = clipIndex == 0
            addLockScreenText(
                to: parentLayer,
                text: formattedLockScreenDate(from: date),
                font: .systemFont(ofSize: TemplateLockScreenOverlay.dateFontSize, weight: .semibold),
                frame: TemplateLockScreenOverlay.videoLayerFrame(
                    fromTopLeftFrame: TemplateLockScreenOverlay.dateTopLeftFrame(renderSize: renderSize),
                    renderHeight: renderSize.height
                ),
                startTime: overlay.textRevealStartTime(for: .date, clipStart: clipStart, isFirstClip: isFirstClip),
                endTime: clipEnd,
                totalDuration: totalDuration,
                shouldFadeIn: isFirstClip
            )
            addLockScreenText(
                to: parentLayer,
                text: formattedLockScreenTime(from: date),
                font: .systemFont(ofSize: 190, weight: .bold),
                frame: TemplateLockScreenOverlay.videoLayerFrame(
                    fromTopLeftFrame: TemplateLockScreenOverlay.timeTopLeftFrame(renderSize: renderSize),
                    renderHeight: renderSize.height
                ),
                startTime: overlay.textRevealStartTime(for: .time, clipStart: clipStart, isFirstClip: isFirstClip),
                endTime: clipEnd,
                totalDuration: totalDuration,
                shouldFadeIn: isFirstClip
            )
            addLockScreenText(
                to: parentLayer,
                text: bottomText,
                font: .systemFont(ofSize: 50, weight: .semibold),
                frame: TemplateLockScreenOverlay.videoLayerFrame(
                    fromTopLeftFrame: TemplateLockScreenOverlay.bottomTextTopLeftFrame(renderSize: renderSize),
                    renderHeight: renderSize.height
                ),
                startTime: overlay.textRevealStartTime(for: .bottomText, clipStart: clipStart, isFirstClip: isFirstClip),
                endTime: clipEnd,
                totalDuration: totalDuration,
                shouldFadeIn: isFirstClip,
                visibleOpacity: TemplateLockScreenOverlay.bottomTextLayerOpacity
            )

            clipStart = clipEnd
        }
    }

    private func addLockScreenText(
        to parentLayer: CALayer,
        text: String,
        font: UIFont,
        frame: CGRect,
        startTime: TimeInterval,
        endTime: TimeInterval,
        totalDuration: TimeInterval,
        shouldFadeIn: Bool,
        visibleOpacity: Float = 1
    ) {
        guard endTime > startTime else {
            return
        }

        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.16)
        shadow.shadowOffset = CGSize(width: 0, height: 2)
        shadow.shadowBlurRadius = 6

        let textLayer = CALayer()
        textLayer.frame = frame
        textLayer.contentsGravity = .resizeAspect
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.opacity = 0
        textLayer.contents = makeAdvancedTextImage(
            text: text,
            font: font,
            color: .white,
            size: frame.size,
            shadow: shadow,
            glow: nil,
            stroke: nil,
            fillExpansion: nil,
            lineHeightMultiple: 1,
            referenceText: text
        )?.cgImage
        parentLayer.addSublayer(textLayer)
        addLockScreenOpacityAnimation(
            to: textLayer,
            startTime: startTime,
            endTime: endTime,
            totalDuration: totalDuration,
            shouldFadeIn: shouldFadeIn,
            visibleOpacity: visibleOpacity
        )
    }

    private func addLockScreenControl(
        to parentLayer: CALayer,
        systemImageName: String,
        fallbackSystemImageName: String,
        center: CGPoint
    ) {
        let controlSize: CGFloat = 132
        let buttonLayer = CALayer()
        buttonLayer.frame = CGRect(
            x: center.x - (controlSize / 2),
            y: center.y - (controlSize / 2),
            width: controlSize,
            height: controlSize
        )
        buttonLayer.backgroundColor = UIColor.black.withAlphaComponent(0.36).cgColor
        buttonLayer.cornerRadius = controlSize / 2
        buttonLayer.opacity = 1

        let imageName = UIImage(systemName: systemImageName) == nil ? fallbackSystemImageName : systemImageName
        if let controlImage = makeLockScreenControlImage(systemImageName: imageName), let cgImage = controlImage.cgImage {
            let iconSize = TemplateLockScreenOverlay.controlIconSize(forButtonSize: controlSize)
            let iconLayer = CALayer()
            iconLayer.frame = CGRect(
                x: (controlSize - iconSize) / 2,
                y: (controlSize - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            iconLayer.contents = cgImage
            iconLayer.contentsGravity = .resizeAspect
            iconLayer.contentsScale = UIScreen.main.scale
            buttonLayer.addSublayer(iconLayer)
        }

        parentLayer.addSublayer(buttonLayer)
    }

    private func addLockScreenOpacityAnimation(
        to layer: CALayer,
        startTime: TimeInterval,
        endTime: TimeInterval,
        totalDuration: TimeInterval,
        shouldFadeIn: Bool,
        visibleOpacity: Float = 1
    ) {
        let timing = TemplateLockScreenOverlay.opacityTiming(
            startTime: startTime,
            endTime: endTime,
            totalDuration: totalDuration,
            shouldFadeIn: shouldFadeIn
        )
        let opacityAnimation = makeOverlayOpacityAnimation(
            totalDuration: totalDuration,
            startProgress: timing.startProgress,
            enterProgress: timing.enterProgress,
            exitProgress: timing.exitProgress,
            endProgress: timing.endProgress
        )
        opacityAnimation.values = [0, 0, visibleOpacity, visibleOpacity, 0, 0]
        layer.add(opacityAnimation, forKey: "lockScreenOpacity")
    }

    private func makeLockScreenControlImage(systemImageName: String) -> UIImage? {
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            guard let symbol = UIImage(
                systemName: systemImageName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 88, weight: .semibold)
            ) else {
                return
            }

            let image = symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
            let imageSize = image.size
            let drawRect = CGRect(
                x: (size.width - imageSize.width) / 2,
                y: (size.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            image.draw(in: drawRect)
        }
    }

    private func formattedLockScreenDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: date)
    }

    private func formattedLockScreenTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    private func normalizedText(_ text: String?, fallback: String) -> String {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func addCinematicIntroLayers(
        to parentLayer: CALayer,
        effect: TemplateCinematicIntroEffect,
        totalDuration: TimeInterval,
        includesText: Bool
    ) {
        let introDuration = min(max(effect.duration, 0), totalDuration)
        guard introDuration > 0 else {
            return
        }

        let barHeight = renderSize.height * effect.normalizedBarHeightRatio
        addLetterboxLayer(
            to: parentLayer,
            frame: CGRect(x: 0, y: 0, width: renderSize.width, height: barHeight),
            anchorPoint: CGPoint(x: 0.5, y: 0),
            position: CGPoint(x: renderSize.width / 2, y: 0),
            introDuration: introDuration
        )
        addLetterboxLayer(
            to: parentLayer,
            frame: CGRect(x: 0, y: renderSize.height - barHeight, width: renderSize.width, height: barHeight),
            anchorPoint: CGPoint(x: 0.5, y: 1),
            position: CGPoint(x: renderSize.width / 2, y: renderSize.height),
            introDuration: introDuration
        )

        guard includesText else {
            return
        }

        for layout in TemplateIntroRenderSupport.textLayouts(for: effect.textOverlays, renderSize: renderSize) {
            let textLayer = makeAnimatedTextLayer(for: layout)
            parentLayer.addSublayer(textLayer)

            switch layout.overlay.revealMode {
            case .fade:
                let startProgress = max(0, min(layout.overlay.startTime / totalDuration, 1))
                let endProgress = max(startProgress, min(layout.overlay.endTime / totalDuration, 1))
                let enterProgress = min((layout.overlay.startTime + 0.12) / totalDuration, endProgress)
                let exitProgress = max(enterProgress, min((layout.overlay.endTime - 0.12) / totalDuration, 1))
                let opacityAnimation = makeOverlayOpacityAnimation(
                    totalDuration: totalDuration,
                    startProgress: startProgress,
                    enterProgress: enterProgress,
                    exitProgress: exitProgress,
                    endProgress: endProgress
                )
                textLayer.add(opacityAnimation, forKey: "animatedTextFade")
            case .immediate:
                textLayer.opacity = 1
                let startProgress = max(0, min(layout.overlay.startTime / totalDuration, 1))
                let endProgress = max(startProgress, min(layout.overlay.endTime / totalDuration, 1))
                let opacityAnimation = makeOverlayOpacityAnimation(
                    totalDuration: totalDuration,
                    startProgress: startProgress,
                    enterProgress: startProgress,
                    exitProgress: endProgress,
                    endProgress: endProgress
                )
                opacityAnimation.values = [1, 1, 1, 1, 0, 0]
                textLayer.add(opacityAnimation, forKey: "animatedTextImmediate")
            case .typewriter:
                applyTypewriterAnimation(
                    to: textLayer,
                    overlay: layout.overlay,
                    totalDuration: totalDuration
                )
            }
        }

        addIntroIcons(
            to: parentLayer,
            icons: effect.icons,
            totalDuration: totalDuration
        )
        addIntroSparkles(
            to: parentLayer,
            sparkles: effect.sparkles,
            totalDuration: totalDuration
        )
    }

    private func addIntroSparkles(
        to parentLayer: CALayer,
        sparkles: [TemplateIntroSparkle],
        totalDuration: TimeInterval
    ) {
        for sparkle in sparkles where sparkle.endTime > sparkle.startTime {
            let sparkleLayer = makeSparkleLayer(for: sparkle)
            parentLayer.addSublayer(sparkleLayer)

            let startProgress = max(0, min(sparkle.startTime / totalDuration, 1))
            let endProgress = max(startProgress, min(sparkle.endTime / totalDuration, 1))
            let enterProgress = min((sparkle.startTime + 0.18) / totalDuration, endProgress)
            let exitProgress = max(enterProgress, min((sparkle.endTime - 0.18) / totalDuration, 1))
            let opacityAnimation = makeOverlayOpacityAnimation(
                totalDuration: totalDuration,
                startProgress: startProgress,
                enterProgress: enterProgress,
                exitProgress: exitProgress,
                endProgress: endProgress
            )
            sparkleLayer.add(opacityAnimation, forKey: "sparkleOpacity")

            let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnimation.values = [0.82, 1.06, 0.92, 1.03, 0.86]
            scaleAnimation.keyTimes = [0, 0.2, 0.5, 0.78, 1]
            scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + sparkle.startTime + sparkle.phaseOffset
            scaleAnimation.duration = 1.85
            scaleAnimation.repeatCount = .greatestFiniteMagnitude
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scaleAnimation.isRemovedOnCompletion = false
            sparkleLayer.add(scaleAnimation, forKey: "sparkleTwinkle")

            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotationAnimation.fromValue = -0.25
            rotationAnimation.toValue = 0.25
            rotationAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + sparkle.startTime + sparkle.phaseOffset
            rotationAnimation.duration = 2.4
            rotationAnimation.autoreverses = true
            rotationAnimation.repeatCount = .greatestFiniteMagnitude
            rotationAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            rotationAnimation.isRemovedOnCompletion = false
            sparkleLayer.add(rotationAnimation, forKey: "sparkleRotate")
        }
    }

    private func addIntroIcons(
        to parentLayer: CALayer,
        icons: [TemplateIntroIcon],
        totalDuration: TimeInterval
    ) {
        for icon in icons where icon.endTime > icon.startTime {
            guard let iconLayer = makeIntroIconLayer(for: icon) else {
                continue
            }
            parentLayer.addSublayer(iconLayer)

            let startProgress = max(0, min(icon.startTime / totalDuration, 1))
            let endProgress = max(startProgress, min(icon.endTime / totalDuration, 1))
            let opacityAnimation = makeOverlayOpacityAnimation(
                totalDuration: totalDuration,
                startProgress: startProgress,
                enterProgress: startProgress,
                exitProgress: endProgress,
                endProgress: endProgress
            )
            opacityAnimation.values = [1, 1, 1, 1, 0, 0]
            iconLayer.add(opacityAnimation, forKey: "introIconOpacity")

            switch icon.animationStyle {
            case .rotation:
                let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                let rotationRadians = CGFloat(icon.rotationDegrees * .pi / 180)
                rotationAnimation.fromValue = -rotationRadians
                rotationAnimation.toValue = rotationRadians
                rotationAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + icon.startTime + icon.phaseOffset
                rotationAnimation.duration = 0.55
                rotationAnimation.autoreverses = true
                rotationAnimation.repeatCount = .greatestFiniteMagnitude
                rotationAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
                rotationAnimation.isRemovedOnCompletion = false
                iconLayer.add(rotationAnimation, forKey: "introIconRotate")
            case .pulse:
                let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
                scaleAnimation.values = [0.82, 1.06, 0.92, 1.03, 0.86]
                scaleAnimation.keyTimes = [0, 0.2, 0.5, 0.78, 1]
                scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + icon.startTime + icon.phaseOffset
                scaleAnimation.duration = 1.85
                scaleAnimation.repeatCount = .greatestFiniteMagnitude
                scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                scaleAnimation.isRemovedOnCompletion = false
                iconLayer.add(scaleAnimation, forKey: "introIconPulse")
            }
        }
    }

    private func makeIntroIconLayer(for icon: TemplateIntroIcon) -> CALayer? {
        guard
            let assetURL = icon.imageAsset.assetURL,
            let image = UIImage(contentsOfFile: assetURL.path),
            let cgImage = image.cgImage
        else {
            return nil
        }

        let iconLayer = CALayer()
        iconLayer.frame = TemplateIntroRenderSupport.videoLayerFrame(
            fromTopLeftFrame: TemplateIntroRenderSupport.iconFrame(
                for: icon,
                renderSize: renderSize
            ),
            renderSize: renderSize
        )
        iconLayer.contents = cgImage
        iconLayer.contentsGravity = .resizeAspect
        iconLayer.contentsScale = UIScreen.main.scale
        iconLayer.opacity = 0
        return iconLayer
    }

    private func makeSparkleLayer(for sparkle: TemplateIntroSparkle) -> CALayer {
        let font = AppFontCatalog.uiKitFont(
            "AvenirNext-DemiBold",
            size: CGFloat(sparkle.fontSize),
            fallbackWeight: .bold
        )
        let layerSize = CGSize(width: sparkle.fontSize * 2.4, height: sparkle.fontSize * 2.4)
        let topLeftFrame = CGRect(
            x: (renderSize.width * sparkle.position.normalizedX) - (layerSize.width / 2),
            y: (renderSize.height * sparkle.position.normalizedY) - (layerSize.height / 2),
            width: layerSize.width,
            height: layerSize.height
        )
        let sparkleLayer = CALayer()
        sparkleLayer.frame = TemplateIntroRenderSupport.videoLayerFrame(
            fromTopLeftFrame: topLeftFrame,
            renderSize: renderSize
        )
        sparkleLayer.contentsGravity = .resizeAspect
        sparkleLayer.contentsScale = UIScreen.main.scale
        sparkleLayer.opacity = 0
        sparkleLayer.contents = makeAdvancedTextImage(
            text: sparkle.text,
            font: font,
            color: sparkle.color.uiColor,
            size: layerSize,
            shadow: nil,
            glow: makeGlow(
                from: TemplateTextGlow(
                    color: sparkle.color,
                    blurRadius: 12,
                    opacity: 0.85
                )
            ),
            stroke: nil,
            fillExpansion: nil,
            lineHeightMultiple: 1,
            referenceText: sparkle.text
        )?.cgImage
        return sparkleLayer
    }

    private func addLetterboxLayer(
        to parentLayer: CALayer,
        frame: CGRect,
        anchorPoint: CGPoint,
        position: CGPoint,
        introDuration: TimeInterval
    ) {
        let barLayer = CALayer()
        barLayer.frame = frame
        barLayer.backgroundColor = UIColor.black.cgColor
        barLayer.anchorPoint = anchorPoint
        barLayer.position = position
        parentLayer.addSublayer(barLayer)

        let animation = CABasicAnimation(keyPath: "transform.scale.y")
        animation.fromValue = 1
        animation.toValue = 0
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.duration = introDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        barLayer.add(animation, forKey: "letterboxReveal")
    }

    private func makeAnimatedTextLayer(for layout: TemplateIntroRenderedTextOverlay) -> CALayer {
        let textLayer = CALayer()
        textLayer.frame = TemplateIntroRenderSupport.videoLayerFrame(
            fromTopLeftFrame: layout.frame,
            renderSize: renderSize
        )
        textLayer.contentsGravity = .resizeAspect
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.opacity = 0

        if layout.overlay.revealMode == .fade || layout.overlay.revealMode == .immediate {
            textLayer.contents = layout.image?.cgImage
        }

        return textLayer
    }

    private func applyTypewriterAnimation(
        to textLayer: CALayer,
        overlay: TemplateAnimatedTextOverlay,
        totalDuration: TimeInterval
    ) {
        let resolvedFont = AppFontCatalog.uiKitFont(
            overlay.fontName,
            size: CGFloat(overlay.fontSize),
            fallbackWeight: .bold
        )
        let revealDuration = min(
            max((overlay.endTime - overlay.startTime) * 0.72, 0.8),
            overlay.endTime - overlay.startTime
        )
        let characters = Array(overlay.text)
        let frames = characters.indices.compactMap { index -> CGImage? in
            makeAdvancedTextImage(
                text: String(characters[0...index]),
                font: resolvedFont,
                color: overlay.color.uiColor,
                size: textLayer.bounds.size,
                shadow: overlay.shadow.map(makeShadow),
                glow: overlay.glow.map(makeGlow),
                stroke: overlay.stroke,
                fillExpansion: overlay.fillExpansion,
                lineHeightMultiple: overlay.normalizedLineHeightMultiple,
                referenceText: overlay.text
            )?.cgImage
        }

        guard !frames.isEmpty else {
            return
        }

        textLayer.opacity = 1
        textLayer.contents = frames.last

        let contentsAnimation = CAKeyframeAnimation(keyPath: "contents")
        contentsAnimation.values = frames
        contentsAnimation.calculationMode = .discrete
        contentsAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.startTime
        contentsAnimation.duration = revealDuration
        contentsAnimation.fillMode = .forwards
        contentsAnimation.isRemovedOnCompletion = false
        textLayer.add(contentsAnimation, forKey: "typewriterContents")

        let fadeOutStart = max(overlay.endTime - 0.12, overlay.startTime)
        let opacityAnimation = makeOverlayOpacityAnimation(
            totalDuration: totalDuration,
            startProgress: max(0, min(overlay.startTime / totalDuration, 1)),
            enterProgress: max(0, min(overlay.startTime / totalDuration, 1)),
            exitProgress: max(0, min(fadeOutStart / totalDuration, 1)),
            endProgress: max(0, min(overlay.endTime / totalDuration, 1))
        )
        opacityAnimation.values = [1, 1, 1, 1, 0, 0]
        textLayer.add(opacityAnimation, forKey: "typewriterOpacity")
    }

    private func makeShadow(from shadow: TemplateTextShadow) -> NSShadow {
        let renderedShadow = NSShadow()
        renderedShadow.shadowColor = shadow.color.uiColor
        renderedShadow.shadowOffset = CGSize(width: shadow.offsetX, height: shadow.offsetY)
        renderedShadow.shadowBlurRadius = shadow.blurRadius
        return renderedShadow
    }

    private func makeGlow(from glow: TemplateTextGlow) -> NSShadow {
        let renderedGlow = NSShadow()
        renderedGlow.shadowColor = glow.color.uiColor.withAlphaComponent(CGFloat(glow.opacity))
        renderedGlow.shadowOffset = .zero
        renderedGlow.shadowBlurRadius = glow.blurRadius
        return renderedGlow
    }

    private func makeAttributedText(
        text: String,
        font: UIFont,
        color: UIColor,
        shadow: NSShadow?,
        glow: NSShadow?,
        stroke: TemplateTextStroke?,
        lineBreakMode: NSLineBreakMode,
        lineHeightMultiple: Double
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = lineBreakMode
        paragraphStyle.lineHeightMultiple = CGFloat(lineHeightMultiple)
        let fixedLineHeight = font.pointSize * CGFloat(lineHeightMultiple)
        paragraphStyle.minimumLineHeight = fixedLineHeight
        paragraphStyle.maximumLineHeight = fixedLineHeight

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]

        if let shadow {
            attributes[.shadow] = shadow
        }

        if let glow {
            attributes[.strokeColor] = UIColor.clear
            attributes[.strokeWidth] = 0
            attributes[.shadow] = shadow ?? glow
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    private func export(
        asset: AVAsset,
        videoComposition: AVVideoComposition?,
        audioMix: AVAudioMix? = nil,
        to outputURL: URL
    ) async throws {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw AutoPhotosError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition
        exportSession.audioMix = audioMix

        try await export(exportSession)
    }

    private func export(_ exportSession: AVAssetExportSession) async throws {
        setActiveExportSession(exportSession)
        defer { clearActiveExportSession(exportSession) }

        let exportSessionReference = SendableExportSessionReference(session: exportSession)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSessionReference.session.exportAsynchronously {
                let status = exportSessionReference.session.status
                let error = exportSessionReference.session.error

                switch status {
                case .completed:
                    continuation.resume(returning: ())
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .failed:
                    continuation.resume(throwing: error ?? AutoPhotosError.exportFailed)
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

        async let renderedImage = requestRenderedImage(for: asset)
        async let orientation = requestImageOrientation(for: asset)

        return try await AssetPhotoRepresentation(
            image: renderedImage,
            orientation: orientation
        )
    }

    private func requestRenderedImage(for asset: PHAsset) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.version = .current
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
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

    private func requestImageOrientation(for asset: PHAsset) async throws -> UIImage.Orientation {
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

                _ = data
                continuation.resume(returning: UIImage.Orientation(cgOrientation))
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

    private func exportVideoURL(for identifier: String) async throws -> URL {
        guard let asset = fetchAsset(with: identifier) else {
            throw AutoPhotosError.assetNotFound
        }

        let options = PHVideoRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let exportSession = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AVAssetExportSession, Error>) in
            imageManager.requestExportSession(
                forVideo: asset,
                options: options,
                exportPreset: AVAssetExportPresetHighestQuality
            ) { session, _ in
                guard let session else {
                    continuation.resume(throwing: AutoPhotosError.videoAssetNotFound)
                    return
                }

                continuation.resume(returning: session)
            }
        }

        let outputFileType: AVFileType = exportSession.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
        let outputURL = makeTemporaryURL(
            prefix: "auto-photos-source-video",
            pathExtension: outputFileType == .mp4 ? "mp4" : "mov"
        )
        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFileType
        exportSession.shouldOptimizeForNetworkUse = true

        do {
            try await export(exportSession)
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
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

    private func makeFadeOutAudioMix(
        for compositionTrack: AVCompositionTrack,
        targetDuration: CMTime
    ) -> AVAudioMix? {
        guard targetDuration.isNumeric else {
            return nil
        }

        let targetSeconds = targetDuration.seconds
        guard targetSeconds > 0.2 else {
            return nil
        }

        let maxAllowedFade = max(targetSeconds - 0.05, 0.1)
        let fadeDurationSeconds = min(min(max(targetSeconds * 0.16, 0.45), 1.8), maxAllowedFade)
        let fadeDuration = CMTime(seconds: fadeDurationSeconds, preferredTimescale: 600)
        let fadeStartTime = CMTimeSubtract(targetDuration, fadeDuration)

        let parameters = AVMutableAudioMixInputParameters(track: compositionTrack)
        parameters.setVolume(1, at: .zero)
        parameters.setVolumeRamp(
            fromStartVolume: 1,
            toEndVolume: 0,
            timeRange: CMTimeRange(start: fadeStartTime, duration: fadeDuration)
        )

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [parameters]
        return audioMix
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
        makeAdvancedTextImage(
            text: text,
            font: font,
            color: .white,
            size: size,
            shadow: nil,
            glow: nil,
            stroke: nil,
            fillExpansion: nil,
            lineHeightMultiple: 1,
            referenceText: text
        )
    }

    private func makeAdvancedTextImage(
        text: String,
        font: UIFont,
        color: UIColor,
        size: CGSize,
        shadow: NSShadow?,
        glow: NSShadow?,
        stroke: TemplateTextStroke?,
        fillExpansion: Double?,
        lineHeightMultiple: Double,
        referenceText: String
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale

        let baseAttributedText = makeAttributedText(
            text: text,
            font: font,
            color: color,
            shadow: shadow,
            glow: nil,
            stroke: stroke,
            lineBreakMode: .byWordWrapping,
            lineHeightMultiple: lineHeightMultiple
        )
        let outlineAttributedText = stroke.map {
            makeAttributedText(
                text: text,
                font: font,
                color: $0.color.uiColor,
                shadow: nil,
                glow: nil,
                stroke: nil,
                lineBreakMode: .byWordWrapping,
                lineHeightMultiple: lineHeightMultiple
            )
        }
        let glowAttributedText = glow.map {
            makeAttributedText(
                text: text,
                font: font,
                color: color.withAlphaComponent(0.96),
                shadow: $0,
                glow: $0,
                stroke: stroke,
                lineBreakMode: .byWordWrapping,
                lineHeightMultiple: lineHeightMultiple
            )
        }

        let referenceAttributedText = makeAttributedText(
            text: referenceText,
            font: font,
            color: color,
            shadow: shadow,
            glow: glow,
            stroke: stroke,
            lineBreakMode: .byWordWrapping,
            lineHeightMultiple: lineHeightMultiple
        )

        let measurementText = referenceAttributedText
        let textInsets = makeTextInsets(for: shadow, glow: glow, stroke: stroke)

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let insetBounds = CGRect(
                x: textInsets.left,
                y: textInsets.top,
                width: size.width - textInsets.left - textInsets.right,
                height: size.height - textInsets.top - textInsets.bottom
            )
            let measuredRect = measurementText.boundingRect(
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

            if let stroke, let outlineAttributedText {
                drawOutlinedText(
                    outlineAttributedText,
                    in: drawRect,
                    radius: CGFloat(stroke.width)
                )
            }
            glowAttributedText?.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            if let fillExpansion, fillExpansion > 0 {
                drawExpandedText(
                    baseAttributedText,
                    in: drawRect,
                    expansion: CGFloat(fillExpansion)
                )
            }
            baseAttributedText.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        }
    }

    private func drawOutlinedText(
        _ text: NSAttributedString,
        in rect: CGRect,
        radius: CGFloat
    ) {
        let step = max(radius / 3, 1.4)
        var currentRadius = step

        while currentRadius <= radius {
            let diagonalOffset = currentRadius * 0.707
            let offsets = [
                CGPoint(x: -currentRadius, y: 0),
                CGPoint(x: currentRadius, y: 0),
                CGPoint(x: 0, y: -currentRadius),
                CGPoint(x: 0, y: currentRadius),
                CGPoint(x: -diagonalOffset, y: -diagonalOffset),
                CGPoint(x: diagonalOffset, y: -diagonalOffset),
                CGPoint(x: -diagonalOffset, y: diagonalOffset),
                CGPoint(x: diagonalOffset, y: diagonalOffset),
            ]

            for offset in offsets {
                text.draw(
                    with: rect.offsetBy(dx: offset.x, dy: offset.y),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
            }

            currentRadius += step
        }
    }

    private func drawExpandedText(
        _ text: NSAttributedString,
        in rect: CGRect,
        expansion: CGFloat
    ) {
        let offsets = [
            CGPoint(x: -expansion, y: 0),
            CGPoint(x: expansion, y: 0),
            CGPoint(x: 0, y: -expansion),
            CGPoint(x: 0, y: expansion),
            CGPoint(x: -expansion * 0.7, y: -expansion * 0.7),
            CGPoint(x: expansion * 0.7, y: -expansion * 0.7),
            CGPoint(x: -expansion * 0.7, y: expansion * 0.7),
            CGPoint(x: expansion * 0.7, y: expansion * 0.7),
        ]

        for offset in offsets {
            text.draw(
                with: rect.offsetBy(dx: offset.x, dy: offset.y),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        }
    }

    private func makeTextInsets(
        for shadow: NSShadow?,
        glow: NSShadow?,
        stroke: TemplateTextStroke?
    ) -> UIEdgeInsets {
        let shadowOffset = shadow?.shadowOffset ?? .zero
        let glowBlurRadius = glow?.shadowBlurRadius ?? 0
        let shadowBlurRadius = shadow?.shadowBlurRadius ?? 0
        let strokePadding = stroke.map { abs($0.width) * 1.8 } ?? 0
        let horizontalPadding = max(20, abs(shadowOffset.width) + shadowBlurRadius + glowBlurRadius + strokePadding + 12)
        let verticalPadding = max(12, abs(shadowOffset.height) + shadowBlurRadius + glowBlurRadius + strokePadding + 12)
        return UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
    }

    private func makeTextInsets(for shadow: NSShadow?) -> UIEdgeInsets {
        makeTextInsets(for: shadow, glow: nil, stroke: nil)
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

        context.clear(CGRect(origin: .zero, size: size))
        context.interpolationQuality = .high

        UIGraphicsPushContext(context)
        image.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()

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

    func flippedVertically() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            draw(in: CGRect(origin: .zero, size: size))
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

private extension ColorToken {
    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: 1
        )
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
