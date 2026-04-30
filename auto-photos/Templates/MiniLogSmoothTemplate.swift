//
//  MiniLogSmoothTemplate.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation

extension VideoTemplate {
    static let miniLogSmooth = VideoTemplate(
        id: "minilog-smooth",
        name: "MiniLog Smooth",
        tagline: "12컷 부드러운 리듬 숏폼",
        description: "조금 더 유연한 템포로 12장의 순간을 자연스럽게 이어 붙이는 템플릿",
        photoCount: 12,
        clipDurations: [2.3, 2.0, 2.3, 2.0, 2.3, 2.3, 2.0, 2.3, 2.0, 2.3, 2.6, 2.4],
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        theme: TemplateTheme(
            accent: ColorToken(red: 0.35, green: 0.31, blue: 0.29),
            secondaryAccent: ColorToken(red: 0.90, green: 0.84, blue: 0.78),
            surface: ColorToken(red: 0.97, green: 0.95, blue: 0.93),
            backgroundTop: ColorToken(red: 0.98, green: 0.97, blue: 0.95),
            backgroundBottom: ColorToken(red: 0.91, green: 0.87, blue: 0.84)
        )
    )
}
