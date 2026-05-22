//
//  RestaurantRecommendationTemplate.swift
//  auto-photos
//
//  Created by Codex on 5/19/26.
//

import Foundation

extension VideoTemplate {
    private static let restaurantClipDurations: [TimeInterval] = [
        1.5, 2.0, 1.5, 1.5, 2.0, 1.5, 1.5, 1.5, 1.5, 1.5,
    ]

    private static let restaurantRecommendationIconAsset = TemplateImageAsset(
        resourceName: "restaurant_sparkle",
        fileExtension: "png"
    )

    static let restaurantRecommendation = VideoTemplate(
        id: "restaurant-recommendation",
        name: "오늘의 픽",
        tagline: "첫 씬 1.5초, 이후 맛집 컷 리듬",
        description: "사진 개수 제한 없이 첫 장면에는 중앙 정렬된 메인 문구와 서브 문구, 회전하는 포인트 PNG를 즉시 보여주고 이후 요청한 맛집 컷 리듬으로 이어 붙이는 맛집 추천 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        leadingClipDurations: restaurantClipDurations,
        repeatingClipDuration: 2.0,
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        cinematicIntro: TemplateCinematicIntroEffect(
            duration: 1.5,
            barHeightRatio: 0,
            textOverlays: [
                TemplateAnimatedTextOverlay(
                    text: "요즘 데이트 핫플 여기",
                    startTime: 0,
                    endTime: 1.5,
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
                    revealMode: .immediate,
                    lineHeightMultiple: 1
                ),
                TemplateAnimatedTextOverlay(
                    text: "부암동 데이트코스 추천",
                    startTime: 0,
                    endTime: 1.5,
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
                    revealMode: .immediate,
                    lineHeightMultiple: 1
                ),
            ],
            icons: [
                TemplateIntroIcon(
                    imageAsset: restaurantRecommendationIconAsset,
                    startTime: 0,
                    endTime: 1.5,
                    baseSize: 116,
                    position: TemplateTextPosition(x: 0.18, y: 0.76),
                    scaleMultiplier: 0.75,
                    rotationDegrees: 20,
                    animationStyle: .pulse,
                    phaseOffset: 0
                ),
                TemplateIntroIcon(
                    imageAsset: restaurantRecommendationIconAsset,
                    startTime: 0,
                    endTime: 1.5,
                    baseSize: 96,
                    position: TemplateTextPosition(x: 0.78, y: 0.29),
                    scaleMultiplier: 0.75,
                    rotationDegrees: 20,
                    animationStyle: .pulse,
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

    static let restaurantShortForm = VideoTemplate(
        id: "restaurant-short-form",
        name: "추천 릴스",
        tagline: "1.5초 썸네일 + 맛집 컷 리듬",
        description: "오늘의 픽과 같은 두 문장 인트로 폼을 사용하고, 첫 0초부터 텍스트를 보여주는 추천형 숏폼 템플릿",
        photoCount: 0,
        clipDurations: [],
        usesSelectionCount: true,
        leadingClipDurations: restaurantClipDurations,
        repeatingClipDuration: 2.0,
        audioTrack: .bundled(title: "song01", resourceName: "song01", fileExtension: "wav"),
        textOverlay: nil,
        cinematicIntro: TemplateCinematicIntroEffect(
            duration: 1.5,
            barHeightRatio: 0,
            textOverlays: [
                TemplateAnimatedTextOverlay(
                    text: "오늘 저장할 맛집은 여기",
                    startTime: 0,
                    endTime: 1.5,
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
                    revealMode: .immediate,
                    lineHeightMultiple: 1
                ),
                TemplateAnimatedTextOverlay(
                    text: "두 문장으로 바로 시작",
                    startTime: 0,
                    endTime: 1.5,
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
                    revealMode: .immediate,
                    lineHeightMultiple: 1
                ),
            ]
        ),
        theme: TemplateTheme(
            accent: ColorToken(red: 0.31, green: 0.19, blue: 0.36),
            secondaryAccent: ColorToken(red: 0.82, green: 0.55, blue: 0.92),
            surface: ColorToken(red: 0.98, green: 0.92, blue: 0.98),
            backgroundTop: ColorToken(red: 1.0, green: 0.96, blue: 0.99),
            backgroundBottom: ColorToken(red: 0.91, green: 0.82, blue: 0.94)
        )
    )
}
