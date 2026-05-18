//
//  RestaurantRecommendationTemplate.swift
//  auto-photos
//
//  Created by Codex on 5/19/26.
//

import Foundation

extension VideoTemplate {
    static let restaurantRecommendation = VideoTemplate(
        id: "restaurant-recommendation",
        name: "맛집추천템플릿",
        tagline: "첫 씬 3.5초, 이후 2.0초",
        description: "사진 개수 제한 없이 첫 장면에는 중앙 정렬된 메인 문구와 서브 문구, 반짝이는 별 모션을 보여주고 이후 모든 사진과 Live Photo를 2.0초씩 이어 붙이는 맛집 추천 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        leadingClipDurations: [3.5],
        repeatingClipDuration: 2.0,
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        cinematicIntro: TemplateCinematicIntroEffect(
            duration: 3.5,
            barHeightRatio: 0,
            textOverlays: [
                TemplateAnimatedTextOverlay(
                    text: "요즘 데이트 핫플 여기",
                    startTime: 0,
                    endTime: 3.5,
                    fontName: AppFontName.kotraHope,
                    fontSize: 169,
                    position: TemplateTextPosition(x: 0.5, y: 0.537),
                    maxWidthRatio: 0.9,
                    color: ColorToken(red: 1, green: 1, blue: 1),
                    shadow: nil,
                    glow: nil,
                    stroke: TemplateTextStroke(
                        color: ColorToken(red: 0, green: 0, blue: 0),
                        width: 8
                    ),
                    revealMode: .fade,
                    lineHeightMultiple: 1
                ),
                TemplateAnimatedTextOverlay(
                    text: "부암동 데이트코스 추천",
                    startTime: 0,
                    endTime: 3.5,
                    fontName: AppFontName.kotraHope,
                    fontSize: 64,
                    position: TemplateTextPosition(x: 0.5, y: 0.40),
                    maxWidthRatio: 0.82,
                    color: ColorToken(red: 1, green: 1, blue: 1),
                    shadow: nil,
                    glow: nil,
                    stroke: TemplateTextStroke(
                        color: ColorToken(red: 0, green: 0, blue: 0),
                        width: 7
                    ),
                    stacksBelowPreviousText: true,
                    revealMode: .fade,
                    lineHeightMultiple: 1
                ),
            ],
            sparkles: [
                TemplateIntroSparkle(
                    text: "✦",
                    startTime: 0,
                    endTime: 3.5,
                    fontSize: 116,
                    position: TemplateTextPosition(x: 0.24, y: 0.64),
                    color: ColorToken(red: 1, green: 0.92, blue: 0.28),
                    phaseOffset: 0
                ),
                TemplateIntroSparkle(
                    text: "✦",
                    startTime: 0,
                    endTime: 3.5,
                    fontSize: 96,
                    position: TemplateTextPosition(x: 0.78, y: 0.29),
                    color: ColorToken(red: 1, green: 0.92, blue: 0.28),
                    phaseOffset: 0.36
                ),
            ]
        ),
        theme: TemplateTheme(
            accent: ColorToken(red: 0.23, green: 0.16, blue: 0.12),
            secondaryAccent: ColorToken(red: 1.0, green: 0.72, blue: 0.25),
            surface: ColorToken(red: 0.98, green: 0.94, blue: 0.89),
            backgroundTop: ColorToken(red: 1.0, green: 0.97, blue: 0.93),
            backgroundBottom: ColorToken(red: 0.93, green: 0.86, blue: 0.78)
        )
    )
}
