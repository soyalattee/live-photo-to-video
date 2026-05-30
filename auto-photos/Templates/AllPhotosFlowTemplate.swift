//
//  AllPhotosFlowTemplate.swift
//  auto-photos
//
//  Created by Codex on 5/6/26.
//

import Foundation

extension VideoTemplate {
    static let allPhotosFlow = VideoTemplate(
        id: "all-photos-flow",
        name: "All Photos Flow",
        tagline: "선택한 모든 사진을 1.1초씩 이어붙이기",
        description: "컷 수 제한 없이 고른 모든 사진과 Live Photo를 1.1초 간격으로 세로 영상으로 이어 붙이는 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        repeatingClipDuration: 1.1,
        audioTrack: .bundled(title: "Saltair Drive", resourceName: "Saltair Drive", fileExtension: "wav"),
        textOverlay: nil,
        theme: TemplateTheme(
            accent: ColorToken(red: 0.27, green: 0.24, blue: 0.22),
            secondaryAccent: ColorToken(red: 0.95, green: 0.89, blue: 0.78),
            surface: ColorToken(red: 0.98, green: 0.96, blue: 0.92),
            backgroundTop: ColorToken(red: 0.99, green: 0.98, blue: 0.95),
            backgroundBottom: ColorToken(red: 0.92, green: 0.88, blue: 0.82)
        )
    )
}
