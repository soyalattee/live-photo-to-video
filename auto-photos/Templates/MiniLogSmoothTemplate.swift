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
        audioTrack: TemplateAudioTrack(
            title: "song01",
            bundleResourceName: "song01",
            fileExtension: "wav"
        ),
        textOverlay: nil,
        theme: TemplateTheme(
            accent: ColorToken(red: 0.71, green: 0.53, blue: 0.90),
            secondaryAccent: ColorToken(red: 0.96, green: 0.81, blue: 0.64),
            surface: ColorToken(red: 0.95, green: 0.93, blue: 0.96),
            backgroundTop: ColorToken(red: 0.12, green: 0.15, blue: 0.24),
            backgroundBottom: ColorToken(red: 0.24, green: 0.28, blue: 0.39)
        )
    )
}
