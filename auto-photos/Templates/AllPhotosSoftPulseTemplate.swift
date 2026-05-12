//
//  AllPhotosSoftPulseTemplate.swift
//  auto-photos
//
//  Created by Codex on 5/10/26.
//

import Foundation

extension VideoTemplate {
    static let allPhotosSoftPulse = VideoTemplate(
        id: "all-photos-soft-pulse",
        name: "All Photos Soft Pulse",
        tagline: "첫 컷 2.1초, 이후 1.6초",
        description: "컷 수 제한 없이 첫 장면을 2.1초로 시작하고, 이후 모든 사진과 Live Photo를 1.6초 리듬으로 부드럽게 이어 붙이는 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        leadingClipDurations: [2.1],
        repeatingClipDuration: 1.6,
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        theme: TemplateTheme(
            accent: ColorToken(red: 0.30, green: 0.26, blue: 0.25),
            secondaryAccent: ColorToken(red: 0.93, green: 0.86, blue: 0.80),
            surface: ColorToken(red: 0.98, green: 0.95, blue: 0.92),
            backgroundTop: ColorToken(red: 0.99, green: 0.98, blue: 0.95),
            backgroundBottom: ColorToken(red: 0.92, green: 0.88, blue: 0.84)
        )
    )
}
