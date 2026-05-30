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
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        theme: .brandDefault
    )
}
