//
//  LifeInFraemsTemplate.swift
//  auto-photos
//
//  Created by Codex on 5/13/26.
//

import Foundation

extension VideoTemplate {
    static let lifeInFraems = VideoTemplate(
        id: "life-in-fraems",
        name: "Life Fraems",
        tagline: "24컷 시네마 오프닝 템플릿",
        description: "24장의 사진과 Live Photo를 영화 오프닝처럼 펼쳐내는 세로형 템플릿",
        photoCount: 24,
        clipDurations: [
            2.9,
            0.5, 0.5, 0.5, 0.5, 0.5, 0.5,
            0.6, 0.5, 0.6, 0.5,
            0.5, 0.5, 0.5, 0.5, 0.5,
            1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
            1.1,
            1.3,
        ],
        audioTrack: .bundled(
            title: "life-in-frame",
            resourceName: "life-in-frame",
            fileExtension: "WAV"
        ),
        textOverlay: nil,
        clipMediaModes: (0..<24).map { index in
            if index == 0 || index >= 16 {
                return .livePhotoMotionWhenAvailable
            }

            return .stillImage
        },
        cinematicIntro: TemplateCinematicIntroEffect(
            duration: 2.9,
            barHeightRatio: 0.335,
            textOverlays: [
                TemplateAnimatedTextOverlay(
                    text: "LIFE IN FRAEMS",
                    startTime: 0,
                    endTime: 2.9,
                    fontName: AppFontName.kukdeTopokkiBold,
                    fontSize: 130,
                    position: TemplateTextPosition(x: 0.5, y: 0.49),
                    maxWidthRatio: 0.8,
                    color: ColorToken(red: 1.0, green: 0.6, blue: 0.9372549019607843),
                    shadow: TemplateTextShadow(
                        offsetX: 10,
                        offsetY: 10,
                        blurRadius: 9,
                        color: ColorToken(red: 0.5411764705882353, green: 0, blue: 0)
                    ),
                    glow: nil,
                    revealMode: .typewriter,
                    lineHeightMultiple: 1
                ),
                TemplateAnimatedTextOverlay(
                    text: "A JOURNEY TOLD IN MOMENTS",
                    startTime: 1.6,
                    endTime: 2.9,
                    fontName: "AvenirNext-DemiBold",
                    fontSize: 32,
                    position: TemplateTextPosition(x: 0.5, y: 0.57),
                    maxWidthRatio: 0.8,
                    color: ColorToken(red: 1.0, green: 0.6, blue: 0.9372549019607843),
                    shadow: nil,
                    glow: TemplateTextGlow(
                        color: ColorToken(red: 1.0, green: 0.6, blue: 0.9372549019607843),
                        blurRadius: 14,
                        opacity: 0.72
                    ),
                    revealMode: .fade,
                    lineHeightMultiple: 1
                ),
            ]
        ),
        frameOverlay: TemplateFrameOverlay(
            imageAsset: TemplateImageAsset(
                resourceName: "record_frame",
                fileExtension: "PNG"
            ),
            startTime: 2.9,
            endTime: nil
        ),
        theme: TemplateTheme(
            accent: ColorToken(red: 0.26, green: 0.18, blue: 0.24),
            secondaryAccent: ColorToken(red: 1.0, green: 0.6, blue: 0.9372549019607843),
            surface: ColorToken(red: 0.96, green: 0.92, blue: 0.95),
            backgroundTop: ColorToken(red: 0.99, green: 0.97, blue: 0.99),
            backgroundBottom: ColorToken(red: 0.91, green: 0.85, blue: 0.91)
        ),
        isPremium: true
    )
}
