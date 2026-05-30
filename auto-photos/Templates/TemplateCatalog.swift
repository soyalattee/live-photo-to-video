//
//  TemplateCatalog.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation

enum TemplateCatalog {
    static let templates: [VideoTemplate] = [
        .restaurantRecommendation,
        .restaurantShortForm,
        .lockScreenLog,
        .lifeInFraems,
        .allPhotosFlow,
    ]
}

extension VideoTemplate {
    static let lockScreenLog = VideoTemplate(
        id: "lock-screen-log",
        name: "Lock Screen Log",
        tagline: "잠금화면 날짜 기록 템플릿",
        description: "선택한 모든 리소스의 촬영 날짜와 시간을 아이폰 잠금화면처럼 컷마다 업데이트해 보여주는 세로형 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        leadingClipDurations: [1.5],
        repeatingClipDuration: 1.0,
        audioTrack: .bundled(title: "Tak Before Dawn", resourceName: "Tak Before Dawn", fileExtension: "wav"),
        textOverlay: nil,
        lockScreenOverlay: TemplateLockScreenOverlay(
            defaultBottomText: "여름맞이 ootd 브이로그",
            dateRevealOffset: 0.1,
            timeRevealOffset: 0.2,
            bottomTextRevealOffset: 0.5
        ),
        theme: TemplateTheme(
            accent: ColorToken(red: 0.22, green: 0.22, blue: 0.22),
            secondaryAccent: ColorToken(red: 0.86, green: 0.86, blue: 0.86),
            surface: ColorToken(red: 0.95, green: 0.95, blue: 0.95),
            backgroundTop: ColorToken(red: 0.98, green: 0.98, blue: 0.98),
            backgroundBottom: ColorToken(red: 0.82, green: 0.82, blue: 0.82)
        )
    )
}
