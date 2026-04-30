//
//  MiniLogPulseTemplate.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation

extension VideoTemplate {
    static let miniLogPulse = VideoTemplate(
        id: "minilog-pulse",
        name: "MiniLog Pulse",
        tagline: "12컷 리듬 숏폼",
        description: "선택한 12장의 순간을 타이밍감 있게 이어 붙이는 기본 템플릿",
        photoCount: 12,
        clipDurations: [2.3, 1.5, 2.3, 1.5, 2.3, 2.3, 1.5, 2.3, 1.5, 2.3, 3.1, 2.3],
        audioTrack: TemplateAudioTrack(
            title: "song01",
            bundleResourceName: "song01",
            fileExtension: "wav"
        ),
        textOverlay: nil,
        theme: TemplateTheme(
            accent: ColorToken(red: 0.94, green: 0.39, blue: 0.29),
            secondaryAccent: ColorToken(red: 0.98, green: 0.77, blue: 0.38),
            surface: ColorToken(red: 0.97, green: 0.94, blue: 0.90),
            backgroundTop: ColorToken(red: 0.14, green: 0.15, blue: 0.22),
            backgroundBottom: ColorToken(red: 0.31, green: 0.21, blue: 0.30)
        )
    )
}
