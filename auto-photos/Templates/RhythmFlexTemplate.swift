//
//  RhythmFlexTemplate.swift
//  auto-photos
//
//  Created by Codex on 5/11/26.
//

import Foundation

extension VideoTemplate {
    static let rhythmFlex = VideoTemplate(
        id: "rhythm-flex-9-18",
        name: "Rhythm Flex",
        tagline: "9~18컷 범용 리듬 템플릿",
        description: "9장부터 18장까지 커버하면서 앞, 중간, 후반 구간이 리듬감 있게 확장되는 범용 세로 숏폼 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        minimumPhotoCount: 9,
        maximumPhotoCount: 18,
        dynamicClipPattern: .rhythmFlex918,
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        theme: TemplateTheme(
            accent: ColorToken(red: 0.24, green: 0.20, blue: 0.19),
            secondaryAccent: ColorToken(red: 0.92, green: 0.85, blue: 0.77),
            surface: ColorToken(red: 0.98, green: 0.95, blue: 0.92),
            backgroundTop: ColorToken(red: 0.99, green: 0.97, blue: 0.94),
            backgroundBottom: ColorToken(red: 0.90, green: 0.86, blue: 0.81)
        )
    )
}
