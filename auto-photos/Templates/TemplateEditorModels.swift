//
//  TemplateEditorModels.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation

struct TemplateFontPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let fontName: String

    static let presets: [TemplateFontPreset] = [
        TemplateFontPreset(id: "avenir-condensed", name: "Avenir Condensed Bold", fontName: "AvenirNextCondensed-Bold"),
        TemplateFontPreset(id: "avenir-demi", name: "Avenir DemiBold", fontName: "AvenirNext-DemiBold"),
        TemplateFontPreset(id: "georgia-bold", name: "Georgia Bold", fontName: "Georgia-Bold"),
        TemplateFontPreset(id: "marker-felt", name: "Marker Felt", fontName: "MarkerFelt-Wide"),
        TemplateFontPreset(id: "snell-bold", name: "Snell Roundhand Bold", fontName: "SnellRoundhand-Bold"),
    ]

    static let defaultPreset = presets[0]
}

struct TemplateDraft: Sendable {
    var title: String = ""
    var photoCount: Int = 10
    var clipDurationsText: String = "2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0"
    var audioImportURL: URL?
    var audioDisplayName: String = ""
    var includesText: Bool = false
    var text: String = ""
    var textStartTime: Double = 0
    var textEndTime: Double = 3
    var fontName: String = TemplateFontPreset.defaultPreset.fontName
    var fontSize: Double = 74
    var textPositionX: Double = 0.5
    var textPositionY: Double = 0.18

    var parsedClipDurations: [Double] {
        clipDurationsText
            .split { $0 == "," || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap(Double.init)
    }

    var summaryDescription: String {
        let audioText = audioImportURL == nil ? "무음 또는 직접 선택" : "커스텀 BGM 포함"
        let textState = includesText ? "텍스트 포함" : "텍스트 없음"
        return "직접 만든 템플릿 · \(audioText) · \(textState)"
    }
}

enum TemplateDraftError: LocalizedError {
    case emptyTitle
    case invalidPhotoCount
    case invalidClipDurations(expected: Int, actual: Int)
    case nonPositiveDuration
    case emptyText
    case invalidTextTiming

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "템플릿 제목을 입력해주세요."
        case .invalidPhotoCount:
            return "사진 수는 1장 이상 30장 이하로 설정해주세요."
        case let .invalidClipDurations(expected, actual):
            return "컷 길이는 사진 수와 같아야 해요. 현재 \(actual)개이고, \(expected)개가 필요해요."
        case .nonPositiveDuration:
            return "컷 길이는 모두 0보다 커야 해요."
        case .emptyText:
            return "텍스트 오버레이를 켰다면 표시할 문구를 입력해주세요."
        case .invalidTextTiming:
            return "텍스트 종료 시간은 시작 시간보다 뒤여야 해요."
        }
    }
}
