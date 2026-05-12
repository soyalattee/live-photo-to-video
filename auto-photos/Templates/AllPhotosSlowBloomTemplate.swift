//
//  AllPhotosSlowBloomTemplate.swift
//  auto-photos
//
//  Created by Codex on 5/10/26.
//

import Foundation

extension VideoTemplate {
    static let allPhotosSlowBloom = VideoTemplate(
        id: "all-photos-slow-bloom",
        name: "All Photos Slow Bloom",
        tagline: "첫 컷 2.4초, 이후 2.1초",
        description: "컷 수 제한 없이 첫 장면을 2.4초로 여유 있게 보여주고, 이후 모든 사진과 Live Photo를 2.1초 간격으로 자연스럽게 이어 붙이는 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        leadingClipDurations: [2.4],
        repeatingClipDuration: 2.1,
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        theme: TemplateTheme(
            accent: ColorToken(red: 0.25, green: 0.22, blue: 0.21),
            secondaryAccent: ColorToken(red: 0.89, green: 0.82, blue: 0.77),
            surface: ColorToken(red: 0.97, green: 0.94, blue: 0.91),
            backgroundTop: ColorToken(red: 0.99, green: 0.97, blue: 0.95),
            backgroundBottom: ColorToken(red: 0.90, green: 0.86, blue: 0.82)
        )
    )
}
