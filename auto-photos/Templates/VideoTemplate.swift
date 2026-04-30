//
//  VideoTemplate.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation
import SwiftUI

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

struct ColorToken: Codable, Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
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

struct VideoTemplate: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let description: String
    let photoCount: Int
    let clipDurations: [TimeInterval]
    let audioTrack: TemplateAudioTrack?
    let textOverlay: TemplateTextOverlay?
    let theme: TemplateTheme

    var totalDuration: TimeInterval {
        clipDurations.reduce(0, +)
    }

    var supportsMusic: Bool {
        audioTrack != nil
    }

    var isMusicAvailable: Bool {
        audioTrack?.isAvailable == true
    }

    var supportsText: Bool {
        textOverlay != nil
    }

    var previewRenderOptions: VideoRenderOptions {
        VideoRenderOptions(
            includesMusic: isMusicAvailable,
            includesText: supportsText
        )
    }

    var selectionCaption: String {
        "\(photoCount)장의 사진이 필요해요"
    }

    func validationMessage(for count: Int) -> String? {
        if count < photoCount {
            return "\(photoCount)장 중 \(count)장 선택됨"
        }

        if count > photoCount {
            return "\(photoCount)장까지만 사용할 수 있어요."
        }

        return nil
    }
}
