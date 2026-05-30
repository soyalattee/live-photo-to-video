import Foundation

enum AppLanguage: Equatable, Sendable {
    case korean
    case english
}

struct L10n: Sendable {
    let language: AppLanguage

    init(language: AppLanguage = L10n.currentLanguage()) {
        self.language = language
    }

    static func currentLanguage(locale: Locale = .current) -> AppLanguage {
        language(for: locale.identifier)
    }

    static func language(for localeIdentifier: String?) -> AppLanguage {
        guard let normalized = localeIdentifier?.lowercased() else {
            return .english
        }

        return normalized == "ko" || normalized.hasPrefix("ko-") || normalized.hasPrefix("ko_") ? .korean : .english
    }

    var appName: String { "Locket" }
    var templateGalleryHeadlinePrefix: String { language == .korean ? "오늘을 어떤 무드로" : "How do you want to" }
    var templateGalleryHeadlineAccent: String { language == .korean ? "기억" : "remember" }
    var templateGalleryHeadlineSuffix: String { language == .korean ? "할까요?" : "today?" }
    var templateGallerySubtitle: String { language == .korean ? "원하는 스타일을 골라 기억을 영상으로 남겨보세요." : "Choose a style and turn your memories into a video." }
    var chooseMedia: String { language == .korean ? "미디어 선택하기" : "Choose Media" }
    var chooseTemplateFirst: String { language == .korean ? "템플릿을 먼저 선택하세요" : "Choose a template first" }
    var templateSelectionTitle: String { language == .korean ? "템플릿 선택" : "Template Selection" }
    var selectionConfirmationTitle: String { language == .korean ? "선택 확인" : "Check Selection" }
    var selectedTemplate: String { language == .korean ? "선택된 템플릿" : "Selected Template" }
    var mediaSequence: String { language == .korean ? "미디어 순서" : "Media Sequence" }
    var reselectMedia: String { language == .korean ? "미디어 다시 선택" : "Choose Media Again" }
    var generateVideo: String { language == .korean ? "영상 생성하기" : "Generate Video" }
    var preview: String { language == .korean ? "미리보기" : "Preview" }
    var musicOn: String { language == .korean ? "BGM 포함" : "Music On" }
    var textOn: String { language == .korean ? "텍스트 포함" : "Text On" }
    var saveToCameraRoll: String { language == .korean ? "사진 앱에 저장" : "Save to Camera Roll" }
    var saveSuccessMessage: String { language == .korean ? "선택한 옵션으로 사진 앱에 저장했어요." : "Saved to Photos with the selected options." }
    var saveCompleteTitle: String { language == .korean ? "다운로드 완료" : "Download Complete" }
    var saveCompleteMessage: String { language == .korean ? "영상이 사진 앱에 저장되었어요." : "Your video has been saved to Photos." }
    var saveFailureTitle: String { language == .korean ? "저장 실패" : "Save Failed" }
    var share: String { language == .korean ? "공유하기" : "Share" }
    var shareFailureTitle: String { language == .korean ? "공유 준비 실패" : "Could Not Prepare Share" }
    var home: String { language == .korean ? "홈으로" : "Home" }
    var retrySequence: String { language == .korean ? "순서 다시 보기" : "Review Sequence" }
    var cancel: String { language == .korean ? "취소" : "Cancel" }
    var close: String { language == .korean ? "닫기" : "Close" }
    var titleLabel: String { language == .korean ? "TITLE" : "TITLE" }
    var shortSentenceLabel: String { language == .korean ? "SHORT SENTENCE" : "SHORT SENTENCE" }
    var bottomCaptionLabel: String { language == .korean ? "BOTTOM TEXT" : "BOTTOM TEXT" }
    var textStylePreview: String { language == .korean ? "텍스트 미리보기" : "Text Preview" }
    var textFillColor: String { language == .korean ? "글자색" : "Text Color" }
    var textOutlineColor: String { language == .korean ? "아웃라인" : "Outline" }
    var mediaLoading: String { language == .korean ? "선택한 미디어를 템플릿에 맞게 준비하는 중이에요." : "Preparing your media for the selected template." }
    var errorTitle: String { language == .korean ? "문제가 생겼어요" : "Something went wrong" }
    var tryAgain: String { language == .korean ? "다시 시도" : "Try Again" }
    var startOver: String { language == .korean ? "처음으로" : "Start Over" }
    var templateBGMUnavailable: String { language == .korean ? "템플릿 BGM 파일을 다시 연결하면 BGM 옵션이 자동으로 활성화돼요." : "Reconnect the template BGM file to enable the music option." }
    var textUnavailable: String { language == .korean ? "이 템플릿은 텍스트 오버레이 없이 출력돼요." : "This template exports without text overlays." }

    var paywallTitle: String { language == .korean ? "Locket PRO" : "Locket PRO" }
    var paywallSubtitle: String { language == .korean ? "오늘을 더 감각적으로" : "Elevate your memories" }
    var paywallBenefit1Title: String { language == .korean ? "프리미엄 템플릿" : "Premium Templates" }
    var paywallBenefit1Description: String { language == .korean ? "Lock Screen Log, Life Fraems를 자유롭게" : "Unlock Lock Screen Log & Life Fraems" }
    var paywallBenefit2Title: String { language == .korean ? "워터마크 없이 저장" : "Save Without Watermark" }
    var paywallBenefit2Description: String { language == .korean ? "영상에 로고 없이 깔끔하게 저장돼요" : "Your videos export clean, without a logo" }
    var paywallBenefit3Title: String { language == .korean ? "광고 없이 바로 저장" : "Save Without Ads" }
    var paywallBenefit3Description: String { language == .korean ? "광고 시청 없이 바로 다운로드" : "Download instantly, no ad to watch" }
    var paywallPriceCaption: String { language == .korean ? "주 $1.99 · 자동 갱신 · 언제든 취소 가능" : "$1.99/week · Auto-renews · Cancel anytime" }
    var paywallSubscribeButton: String { language == .korean ? "구독 시작하기" : "Subscribe Now" }
    var paywallRestoreButton: String { language == .korean ? "이미 구독 중이세요? 복원하기" : "Already subscribed? Restore" }
    var purchaseFailedTitle: String { language == .korean ? "결제 실패" : "Purchase Failed" }
    var restoreFailedTitle: String { language == .korean ? "복원 실패" : "Restore Failed" }
    var noSubscriptionFound: String { language == .korean ? "활성 구독이 없어요." : "No active subscription found." }
    var subscriptionPendingMessage: String { language == .korean ? "결제 승인 대기 중이에요. 잠시 후 다시 확인해주세요." : "Purchase is pending approval. Please try again later." }

    func templateTagline(for template: VideoTemplate) -> String {
        switch (language, template.id) {
        case (.english, "restaurant-recommendation"):
            return "3.5s opener, then 2.0s beats"
        case (.english, "lock-screen-log"):
            return "Lock screen date story"
        case (.english, "life-in-fraems"):
            return "24-cut cinematic opener"
        case (.english, "all-photos-flow"):
            return "Every media item in a 1.1s flow"
        case (.korean, "all-photos-flow"):
            return "선택한 모든 미디어를 1.1초씩 이어붙이기"
        default:
            return template.tagline
        }
    }
}
