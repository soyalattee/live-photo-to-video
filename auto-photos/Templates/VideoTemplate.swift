//
//  VideoTemplate.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation
import SwiftUI
import UIKit

enum TemplateAudioSource: String, Codable, Hashable, Sendable {
    case bundle
    case imported
}

enum TemplateStoragePaths {
    static var audioDirectory: URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseDirectory.appendingPathComponent("TemplateAudio", isDirectory: true)
    }
}

struct TemplateAudioTrack: Codable, Equatable, Hashable, Sendable {
    let title: String
    let source: TemplateAudioSource
    let resourceName: String
    let fileExtension: String

    var assetURL: URL? {
        switch source {
        case .bundle:
            return Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
        case .imported:
            let url = TemplateStoragePaths.audioDirectory
                .appendingPathComponent(resourceName)
                .appendingPathExtension(fileExtension)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    var isAvailable: Bool {
        assetURL != nil
    }

    static func bundled(title: String, resourceName: String, fileExtension: String) -> TemplateAudioTrack {
        TemplateAudioTrack(
            title: title,
            source: .bundle,
            resourceName: resourceName,
            fileExtension: fileExtension
        )
    }

    static func imported(title: String, resourceName: String, fileExtension: String) -> TemplateAudioTrack {
        TemplateAudioTrack(
            title: title,
            source: .imported,
            resourceName: resourceName,
            fileExtension: fileExtension
        )
    }
}

struct TemplateImageAsset: Codable, Equatable, Hashable, Sendable {
    let resourceName: String
    let fileExtension: String

    var assetURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }
}

struct TemplateTextPosition: Codable, Equatable, Hashable, Sendable {
    let x: Double
    let y: Double

    var normalizedX: Double {
        min(max(x, 0.1), 0.9)
    }

    var normalizedY: Double {
        min(max(y, 0.08), 0.92)
    }
}

struct TemplateTextOverlay: Codable, Equatable, Hashable, Sendable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let fontName: String
    let fontSize: Double
    let position: TemplateTextPosition
}

enum TemplateClipMediaMode: String, Codable, Equatable, Hashable, Sendable {
    case automatic
    case stillImage
    case livePhotoMotionWhenAvailable
}

enum TemplateTextRevealMode: String, Codable, Equatable, Hashable, Sendable {
    case fade
    case immediate
    case typewriter
}

struct TemplateTextShadow: Codable, Equatable, Hashable, Sendable {
    let offsetX: Double
    let offsetY: Double
    let blurRadius: Double
    let color: ColorToken
}

struct TemplateTextGlow: Codable, Equatable, Hashable, Sendable {
    let color: ColorToken
    let blurRadius: Double
    let opacity: Double
}

struct TemplateTextStroke: Codable, Equatable, Hashable, Sendable {
    let color: ColorToken
    let width: Double
}

struct TemplateIntroSparkle: Codable, Equatable, Hashable, Sendable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let fontSize: Double
    let position: TemplateTextPosition
    let color: ColorToken
    let phaseOffset: Double
}

enum TemplateIntroIconAnimationStyle: String, Codable, Equatable, Hashable, Sendable {
    case rotation
    case pulse
}

struct TemplateIntroIcon: Codable, Equatable, Hashable, Sendable {
    let imageAsset: TemplateImageAsset
    let startTime: TimeInterval
    let endTime: TimeInterval
    let baseSize: Double
    let position: TemplateTextPosition
    let scaleMultiplier: Double
    let rotationDegrees: Double
    let animationStyle: TemplateIntroIconAnimationStyle
    let phaseOffset: Double

    init(
        imageAsset: TemplateImageAsset,
        startTime: TimeInterval,
        endTime: TimeInterval,
        baseSize: Double,
        position: TemplateTextPosition,
        scaleMultiplier: Double,
        rotationDegrees: Double,
        animationStyle: TemplateIntroIconAnimationStyle = .rotation,
        phaseOffset: Double
    ) {
        self.imageAsset = imageAsset
        self.startTime = startTime
        self.endTime = endTime
        self.baseSize = baseSize
        self.position = position
        self.scaleMultiplier = scaleMultiplier
        self.rotationDegrees = rotationDegrees
        self.animationStyle = animationStyle
        self.phaseOffset = phaseOffset
    }

    private enum CodingKeys: String, CodingKey {
        case imageAsset
        case startTime
        case endTime
        case baseSize
        case position
        case scaleMultiplier
        case rotationDegrees
        case animationStyle
        case phaseOffset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageAsset = try container.decode(TemplateImageAsset.self, forKey: .imageAsset)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        baseSize = try container.decode(Double.self, forKey: .baseSize)
        position = try container.decode(TemplateTextPosition.self, forKey: .position)
        scaleMultiplier = try container.decode(Double.self, forKey: .scaleMultiplier)
        rotationDegrees = try container.decode(Double.self, forKey: .rotationDegrees)
        animationStyle = try container.decodeIfPresent(TemplateIntroIconAnimationStyle.self, forKey: .animationStyle) ?? .rotation
        phaseOffset = try container.decode(Double.self, forKey: .phaseOffset)
    }
}

struct TemplateAnimatedTextOverlay: Codable, Equatable, Hashable, Sendable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let fontName: String
    let fontSize: Double
    let position: TemplateTextPosition
    let maxWidthRatio: Double
    let color: ColorToken
    let shadow: TemplateTextShadow?
    let glow: TemplateTextGlow?
    let stroke: TemplateTextStroke?
    let fillExpansion: Double?
    let stacksBelowPreviousText: Bool
    let revealMode: TemplateTextRevealMode
    let lineHeightMultiple: Double

    enum CodingKeys: String, CodingKey {
        case text
        case startTime
        case endTime
        case fontName
        case fontSize
        case position
        case maxWidthRatio
        case color
        case shadow
        case glow
        case stroke
        case fillExpansion
        case stacksBelowPreviousText
        case revealMode
        case lineHeightMultiple
    }

    init(
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        fontName: String,
        fontSize: Double,
        position: TemplateTextPosition,
        maxWidthRatio: Double,
        color: ColorToken,
        shadow: TemplateTextShadow?,
        glow: TemplateTextGlow?,
        stroke: TemplateTextStroke? = nil,
        fillExpansion: Double? = nil,
        stacksBelowPreviousText: Bool = false,
        revealMode: TemplateTextRevealMode,
        lineHeightMultiple: Double
    ) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.fontName = fontName
        self.fontSize = fontSize
        self.position = position
        self.maxWidthRatio = maxWidthRatio
        self.color = color
        self.shadow = shadow
        self.glow = glow
        self.stroke = stroke
        self.fillExpansion = fillExpansion
        self.stacksBelowPreviousText = stacksBelowPreviousText
        self.revealMode = revealMode
        self.lineHeightMultiple = lineHeightMultiple
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        position = try container.decode(TemplateTextPosition.self, forKey: .position)
        maxWidthRatio = try container.decode(Double.self, forKey: .maxWidthRatio)
        color = try container.decode(ColorToken.self, forKey: .color)
        shadow = try container.decodeIfPresent(TemplateTextShadow.self, forKey: .shadow)
        glow = try container.decodeIfPresent(TemplateTextGlow.self, forKey: .glow)
        stroke = try container.decodeIfPresent(TemplateTextStroke.self, forKey: .stroke)
        fillExpansion = try container.decodeIfPresent(Double.self, forKey: .fillExpansion)
        stacksBelowPreviousText = try container.decodeIfPresent(Bool.self, forKey: .stacksBelowPreviousText) ?? false
        revealMode = try container.decode(TemplateTextRevealMode.self, forKey: .revealMode)
        lineHeightMultiple = try container.decode(Double.self, forKey: .lineHeightMultiple)
    }

    var normalizedMaxWidthRatio: Double {
        min(max(maxWidthRatio, 0.2), 1)
    }

    var normalizedLineHeightMultiple: Double {
        min(max(lineHeightMultiple, 0.8), 2)
    }
}

struct TemplateCinematicIntroEffect: Codable, Equatable, Sendable {
    let duration: TimeInterval
    let barHeightRatio: Double
    let textOverlays: [TemplateAnimatedTextOverlay]
    let sparkles: [TemplateIntroSparkle]
    let icons: [TemplateIntroIcon]

    enum CodingKeys: String, CodingKey {
        case duration
        case barHeightRatio
        case textOverlays
        case sparkles
        case icons
    }

    init(
        duration: TimeInterval,
        barHeightRatio: Double,
        textOverlays: [TemplateAnimatedTextOverlay],
        sparkles: [TemplateIntroSparkle] = [],
        icons: [TemplateIntroIcon] = []
    ) {
        self.duration = duration
        self.barHeightRatio = barHeightRatio
        self.textOverlays = textOverlays
        self.sparkles = sparkles
        self.icons = icons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        barHeightRatio = try container.decode(Double.self, forKey: .barHeightRatio)
        textOverlays = try container.decode([TemplateAnimatedTextOverlay].self, forKey: .textOverlays)
        sparkles = try container.decodeIfPresent([TemplateIntroSparkle].self, forKey: .sparkles) ?? []
        icons = try container.decodeIfPresent([TemplateIntroIcon].self, forKey: .icons) ?? []
    }

    var normalizedBarHeightRatio: Double {
        min(max(barHeightRatio, 0), 0.45)
    }
}

struct TemplateFrameOverlay: Codable, Equatable, Hashable, Sendable {
    let imageAsset: TemplateImageAsset
    let startTime: TimeInterval
    let endTime: TimeInterval?
}

struct TemplateLockScreenOverlay: Codable, Equatable, Hashable, Sendable {
    let defaultBottomText: String
    let dateRevealOffset: TimeInterval
    let timeRevealOffset: TimeInterval
    let bottomTextRevealOffset: TimeInterval

    static let dateFontSize: CGFloat = 56
    static let bottomTextLayerOpacity: Float = 0.9

    enum TextElement: Sendable {
        case date
        case time
        case bottomText
    }

    struct OpacityTiming: Equatable, Sendable {
        let startProgress: Double
        let enterProgress: Double
        let exitProgress: Double
        let endProgress: Double
    }

    func textRevealStartTime(
        for element: TextElement,
        clipStart: TimeInterval,
        isFirstClip: Bool
    ) -> TimeInterval {
        guard isFirstClip else {
            return clipStart
        }

        switch element {
        case .date:
            return clipStart + dateRevealOffset
        case .time:
            return clipStart + timeRevealOffset
        case .bottomText:
            return clipStart + bottomTextRevealOffset
        }
    }

    static func videoLayerFrame(fromTopLeftFrame frame: CGRect, renderHeight: CGFloat) -> CGRect {
        CGRect(
            x: frame.minX,
            y: renderHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func videoLayerY(fromTopLeftCenterY centerY: CGFloat, renderHeight: CGFloat) -> CGFloat {
        renderHeight - centerY
    }

    static func dateTopLeftFrame(renderSize: CGSize) -> CGRect {
        CGRect(x: 120, y: 160, width: renderSize.width - 240, height: 88)
    }

    static func timeTopLeftFrame(renderSize: CGSize) -> CGRect {
        CGRect(x: 72, y: 238, width: renderSize.width - 144, height: 220)
    }

    static func bottomTextTopLeftFrame(renderSize: CGSize) -> CGRect {
        CGRect(x: 80, y: 1498, width: renderSize.width - 160, height: 112)
    }

    static func controlIconSize(forButtonSize buttonSize: CGFloat) -> CGFloat {
        min(buttonSize * 0.66, buttonSize - 28)
    }

    static func opacityTiming(
        startTime: TimeInterval,
        endTime: TimeInterval,
        totalDuration: TimeInterval,
        shouldFadeIn: Bool
    ) -> OpacityTiming {
        let startProgress = max(0, min(startTime / totalDuration, 1))
        let endProgress = max(startProgress, min(endTime / totalDuration, 1))
        let enterProgress = shouldFadeIn ? min((startTime + 0.08) / totalDuration, endProgress) : startProgress

        return OpacityTiming(
            startProgress: startProgress,
            enterProgress: enterProgress,
            exitProgress: endProgress,
            endProgress: endProgress
        )
    }
}

struct TemplateCinematicTextCustomization: Equatable, Hashable, Sendable {
    var primaryText: String
    var secondaryText: String
    var primaryFontName: String
    var secondaryFontName: String
    var textColor: ColorToken
    var shadowColor: ColorToken
}

struct ColorToken: Codable, Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }
}

struct TemplateTheme: Codable, Equatable, Sendable {
    let accent: ColorToken
    let secondaryAccent: ColorToken
    let surface: ColorToken
    let backgroundTop: ColorToken
    let backgroundBottom: ColorToken

    static let brandDefault = TemplateTheme(
        accent: ColorToken(red: 0.22, green: 0.19, blue: 0.18),
        secondaryAccent: ColorToken(red: 0.83, green: 0.77, blue: 0.71),
        surface: ColorToken(red: 0.97, green: 0.95, blue: 0.92),
        backgroundTop: ColorToken(red: 0.98, green: 0.97, blue: 0.95),
        backgroundBottom: ColorToken(red: 0.91, green: 0.87, blue: 0.83)
    )
}

enum DynamicClipPattern: String, Codable, Equatable, Sendable {
    case repeatAll
    case rhythmFlex918
}

struct VideoTemplate: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let description: String
    let photoCount: Int
    let clipDurations: [TimeInterval]
    let usesSelectionCount: Bool
    let minimumPhotoCount: Int?
    let maximumPhotoCount: Int?
    let leadingClipDurations: [TimeInterval]
    let repeatingClipDuration: TimeInterval?
    let dynamicClipPattern: DynamicClipPattern
    let audioTrack: TemplateAudioTrack?
    let textOverlay: TemplateTextOverlay?
    let clipMediaModes: [TemplateClipMediaMode]?
    let cinematicIntro: TemplateCinematicIntroEffect?
    let frameOverlay: TemplateFrameOverlay?
    let lockScreenOverlay: TemplateLockScreenOverlay?
    let theme: TemplateTheme
    let isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tagline
        case description
        case photoCount
        case clipDurations
        case usesSelectionCount
        case minimumPhotoCount
        case maximumPhotoCount
        case leadingClipDurations
        case repeatingClipDuration
        case dynamicClipPattern
        case audioTrack
        case textOverlay
        case clipMediaModes
        case cinematicIntro
        case frameOverlay
        case lockScreenOverlay
        case theme
        case isPremium
    }

    init(
        id: String,
        name: String,
        tagline: String,
        description: String,
        photoCount: Int,
        clipDurations: [TimeInterval],
        usesSelectionCount: Bool = false,
        minimumPhotoCount: Int? = nil,
        maximumPhotoCount: Int? = nil,
        leadingClipDurations: [TimeInterval] = [],
        repeatingClipDuration: TimeInterval? = nil,
        dynamicClipPattern: DynamicClipPattern = .repeatAll,
        audioTrack: TemplateAudioTrack?,
        textOverlay: TemplateTextOverlay?,
        clipMediaModes: [TemplateClipMediaMode]? = nil,
        cinematicIntro: TemplateCinematicIntroEffect? = nil,
        frameOverlay: TemplateFrameOverlay? = nil,
        lockScreenOverlay: TemplateLockScreenOverlay? = nil,
        theme: TemplateTheme,
        isPremium: Bool = false
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.description = description
        self.photoCount = photoCount
        self.clipDurations = clipDurations
        self.usesSelectionCount = usesSelectionCount
        self.minimumPhotoCount = minimumPhotoCount
        self.maximumPhotoCount = maximumPhotoCount
        self.leadingClipDurations = leadingClipDurations
        self.repeatingClipDuration = repeatingClipDuration
        self.dynamicClipPattern = dynamicClipPattern
        self.audioTrack = audioTrack
        self.textOverlay = textOverlay
        self.clipMediaModes = clipMediaModes
        self.cinematicIntro = cinematicIntro
        self.frameOverlay = frameOverlay
        self.lockScreenOverlay = lockScreenOverlay
        self.theme = theme
        self.isPremium = isPremium
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tagline = try container.decode(String.self, forKey: .tagline)
        description = try container.decode(String.self, forKey: .description)
        photoCount = try container.decode(Int.self, forKey: .photoCount)
        clipDurations = try container.decode([TimeInterval].self, forKey: .clipDurations)
        usesSelectionCount = try container.decodeIfPresent(Bool.self, forKey: .usesSelectionCount) ?? false
        minimumPhotoCount = try container.decodeIfPresent(Int.self, forKey: .minimumPhotoCount)
        maximumPhotoCount = try container.decodeIfPresent(Int.self, forKey: .maximumPhotoCount)
        leadingClipDurations = try container.decodeIfPresent([TimeInterval].self, forKey: .leadingClipDurations) ?? []
        repeatingClipDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .repeatingClipDuration)
        dynamicClipPattern = try container.decodeIfPresent(DynamicClipPattern.self, forKey: .dynamicClipPattern) ?? .repeatAll
        audioTrack = try container.decodeIfPresent(TemplateAudioTrack.self, forKey: .audioTrack)
        textOverlay = try container.decodeIfPresent(TemplateTextOverlay.self, forKey: .textOverlay)
        clipMediaModes = try container.decodeIfPresent([TemplateClipMediaMode].self, forKey: .clipMediaModes)
        cinematicIntro = try container.decodeIfPresent(TemplateCinematicIntroEffect.self, forKey: .cinematicIntro)
        frameOverlay = try container.decodeIfPresent(TemplateFrameOverlay.self, forKey: .frameOverlay)
        lockScreenOverlay = try container.decodeIfPresent(TemplateLockScreenOverlay.self, forKey: .lockScreenOverlay)
        theme = try container.decode(TemplateTheme.self, forKey: .theme)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
    }

    var totalDuration: TimeInterval {
        if usesSelectionCount {
            return repeatingClipDuration ?? 0
        }

        return clipDurations.reduce(0, +)
    }

    var supportsMusic: Bool {
        audioTrack != nil
    }

    var isMusicAvailable: Bool {
        audioTrack?.isAvailable == true
    }

    var supportsText: Bool {
        textOverlay != nil || cinematicIntro?.textOverlays.isEmpty == false || lockScreenOverlay != nil
    }

    var previewRenderOptions: VideoRenderOptions {
        VideoRenderOptions(
            includesMusic: isMusicAvailable,
            includesText: supportsText
        )
    }

    var supportsCinematicTextCustomization: Bool {
        defaultCinematicTextCustomization != nil || lockScreenOverlay != nil
    }

    var defaultCinematicTextCustomization: TemplateCinematicTextCustomization? {
        if let lockScreenOverlay {
            return TemplateCinematicTextCustomization(
                primaryText: "",
                secondaryText: lockScreenOverlay.defaultBottomText,
                primaryFontName: "AvenirNext-DemiBold",
                secondaryFontName: "AvenirNext-DemiBold",
                textColor: ColorToken(red: 1, green: 1, blue: 1),
                shadowColor: ColorToken(red: 0, green: 0, blue: 0)
            )
        }

        guard
            let cinematicIntro,
            let primaryOverlay = cinematicIntro.textOverlays.first,
            let secondaryOverlay = cinematicIntro.textOverlays.dropFirst().first
        else {
            return nil
        }

        return TemplateCinematicTextCustomization(
            primaryText: primaryOverlay.text,
            secondaryText: secondaryOverlay.text,
            primaryFontName: primaryOverlay.fontName,
            secondaryFontName: secondaryOverlay.fontName,
            textColor: primaryOverlay.color,
            shadowColor: primaryOverlay.shadow?.color ?? ColorToken(red: 0, green: 0, blue: 0)
        )
    }

    func clipMediaMode(for clipIndex: Int) -> TemplateClipMediaMode {
        guard let clipMediaModes, clipMediaModes.indices.contains(clipIndex) else {
            return .automatic
        }

        return clipMediaModes[clipIndex]
    }

    func resolvedCinematicIntro(
        customization: TemplateCinematicTextCustomization?
    ) -> TemplateCinematicIntroEffect? {
        guard let cinematicIntro else {
            return nil
        }

        guard let customization else {
            return cinematicIntro
        }

        var updatedOverlays = cinematicIntro.textOverlays

        if let primaryOverlay = updatedOverlays.first {
            updatedOverlays[0] = TemplateAnimatedTextOverlay(
                text: customization.primaryText.normalizedTemplateText(fallback: primaryOverlay.text),
                startTime: primaryOverlay.startTime,
                endTime: primaryOverlay.endTime,
                fontName: customization.primaryFontName,
                fontSize: primaryOverlay.fontSize,
                position: primaryOverlay.position,
                maxWidthRatio: primaryOverlay.maxWidthRatio,
                color: customization.textColor,
                shadow: primaryOverlay.shadow.map {
                    TemplateTextShadow(
                        offsetX: $0.offsetX,
                        offsetY: $0.offsetY,
                        blurRadius: $0.blurRadius,
                        color: customization.shadowColor
                    )
                },
                glow: primaryOverlay.glow,
                stroke: primaryOverlay.stroke.map {
                    TemplateTextStroke(
                        color: customization.shadowColor,
                        width: $0.width
                    )
                },
                fillExpansion: primaryOverlay.fillExpansion,
                stacksBelowPreviousText: primaryOverlay.stacksBelowPreviousText,
                revealMode: primaryOverlay.revealMode,
                lineHeightMultiple: primaryOverlay.lineHeightMultiple
            )
        }

        if updatedOverlays.indices.contains(1) {
            let secondaryOverlay = updatedOverlays[1]
            updatedOverlays[1] = TemplateAnimatedTextOverlay(
                text: customization.secondaryText.normalizedTemplateText(fallback: secondaryOverlay.text),
                startTime: secondaryOverlay.startTime,
                endTime: secondaryOverlay.endTime,
                fontName: customization.secondaryFontName,
                fontSize: secondaryOverlay.fontSize,
                position: secondaryOverlay.position,
                maxWidthRatio: secondaryOverlay.maxWidthRatio,
                color: customization.textColor,
                shadow: secondaryOverlay.shadow,
                glow: secondaryOverlay.glow,
                stroke: secondaryOverlay.stroke.map {
                    TemplateTextStroke(
                        color: customization.shadowColor,
                        width: $0.width
                    )
                },
                fillExpansion: secondaryOverlay.fillExpansion,
                stacksBelowPreviousText: secondaryOverlay.stacksBelowPreviousText,
                revealMode: secondaryOverlay.revealMode,
                lineHeightMultiple: secondaryOverlay.lineHeightMultiple
            )
        }

        return TemplateCinematicIntroEffect(
            duration: cinematicIntro.duration,
            barHeightRatio: cinematicIntro.barHeightRatio,
            textOverlays: updatedOverlays,
            sparkles: cinematicIntro.sparkles,
            icons: cinematicIntro.icons
        )
    }

    var selectionCaption: String {
        if usesSelectionCount {
            if let minimumPhotoCount, let maximumPhotoCount {
                return "\(minimumPhotoCount)~\(maximumPhotoCount)장의 사진을 사용할 수 있어요"
            }

            if let maximumPhotoCount {
                return "최대 \(maximumPhotoCount)장의 사진을 사용할 수 있어요"
            }

            return "선택한 모든 사진을 사용해요"
        }

        return "\(photoCount)장의 사진이 필요해요"
    }

    func validationMessage(for count: Int) -> String? {
        if usesSelectionCount {
            if let minimumPhotoCount, count < minimumPhotoCount {
                return "\(minimumPhotoCount)장 이상 선택해주세요. 현재 \(count)장"
            }

            if let maximumPhotoCount, count > maximumPhotoCount {
                return "\(maximumPhotoCount)장까지만 사용할 수 있어요."
            }

            return nil
        }

        if count < photoCount {
            return "\(photoCount)장 중 \(count)장 선택됨"
        }

        if count > photoCount {
            return "\(photoCount)장까지만 사용할 수 있어요."
        }

        return nil
    }

    func resolvedPhotoCount(for selectedCount: Int) -> Int {
        usesSelectionCount ? selectedCount : photoCount
    }

    func resolvedClipDurations(for selectedCount: Int) -> [TimeInterval] {
        if usesSelectionCount {
            guard selectedCount > 0 else {
                return []
            }

            switch dynamicClipPattern {
            case .repeatAll:
                break
            case .rhythmFlex918:
                return Self.makeRhythmFlex918Durations(for: selectedCount)
            }

            var durations: [TimeInterval] = []
            let prefixCount = min(leadingClipDurations.count, selectedCount)

            if prefixCount > 0 {
                durations.append(contentsOf: leadingClipDurations.prefix(prefixCount))
            }

            if let repeatingClipDuration, selectedCount > prefixCount {
                durations.append(contentsOf: Array(repeating: repeatingClipDuration, count: selectedCount - prefixCount))
            }

            return durations
        }

        return clipDurations
    }

    func totalDuration(for selectedCount: Int) -> TimeInterval {
        resolvedClipDurations(for: selectedCount).reduce(0, +)
    }

    var countBadgeText: String {
        if usesSelectionCount {
            if let minimumPhotoCount, let maximumPhotoCount {
                return "\(minimumPhotoCount)-\(maximumPhotoCount)"
            }

            if let maximumPhotoCount {
                return "1-\(maximumPhotoCount)"
            }

            return "ALL"
        }

        return "\(photoCount)"
    }

    var durationBadgeText: String {
        if usesSelectionCount {
            if dynamicClipPattern == .rhythmFlex918 {
                return "1.2~1.8s rhythm"
            }

            if
                leadingClipDurations.count == 1,
                let firstClipDuration = leadingClipDurations.first,
                let repeatingClipDuration
            {
                return String(format: "%.1fs -> %.1fs", firstClipDuration, repeatingClipDuration)
            }

            if let repeatingClipDuration {
                return String(format: "%.1fs / cut", repeatingClipDuration)
            }
        }

        return String(format: "%.1fs", totalDuration)
    }

    var dynamicDurationHint: String? {
        guard usesSelectionCount else {
            return nil
        }

        if dynamicClipPattern == .rhythmFlex918 {
            return "9~18장 범위에서 앞, 중간, 후반 리듬 구간이 자연스럽게 확장돼요."
        }

        if
            leadingClipDurations.count == 1,
            let firstClipDuration = leadingClipDurations.first,
            let repeatingClipDuration
        {
            return String(format: "첫 컷 %.1f초, 이후 %.1f초씩 적용돼요.", firstClipDuration, repeatingClipDuration)
        }

        if let repeatingClipDuration {
            return String(format: "사진마다 %.1f초씩 적용돼요.", repeatingClipDuration)
        }

        return nil
    }

    var isCustomTemplate: Bool {
        id.hasPrefix("custom-")
    }

    var maximumSelectionCount: Int? {
        usesSelectionCount ? maximumPhotoCount : photoCount
    }

    private static func makeRhythmFlex918Durations(for selectedCount: Int) -> [TimeInterval] {
        guard (9...18).contains(selectedCount) else {
            return []
        }

        var durations: [TimeInterval] = [1.8, 1.6, 1.6]
        let earlyExtras = min(max(selectedCount - 9, 0), 3)
        durations.append(contentsOf: Array(repeating: 1.6, count: earlyExtras))

        durations.append(1.8)

        let midExtras = min(max(selectedCount - 12, 0), 3)
        durations.append(contentsOf: Array(repeating: 1.6, count: midExtras))

        durations.append(contentsOf: [1.4, 1.4, 1.6, 1.2, 1.2])

        let lateExtras = min(max(selectedCount - 15, 0), 3)
        durations.append(contentsOf: Array(repeating: 1.2, count: lateExtras))

        return durations
    }
}

private extension String {
    func normalizedTemplateText(fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : self
    }
}
