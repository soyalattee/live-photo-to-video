//
//  VideoTemplate.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation
import SwiftUI

struct TemplateAudioTrack: Equatable, Sendable {
    let title: String
    let bundleResourceName: String?
    let fileExtension: String?

    var bundleURL: URL? {
        guard let bundleResourceName, let fileExtension else {
            return nil
        }

        return Bundle.main.url(forResource: bundleResourceName, withExtension: fileExtension)
    }

    var isAvailable: Bool {
        bundleURL != nil
    }
}

struct TemplateTextOverlay: Equatable, Sendable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

struct ColorToken: Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

struct TemplateTheme: Equatable, Sendable {
    let accent: ColorToken
    let secondaryAccent: ColorToken
    let surface: ColorToken
    let backgroundTop: ColorToken
    let backgroundBottom: ColorToken
}

struct VideoTemplate: Identifiable, Equatable, Sendable {
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
