import Foundation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum RewardedAdError: LocalizedError {
    case adNotReady
    case presentationFailed(Error)
    case rewardNotEarned

    var errorDescription: String? { userMessage(using: L10n()) }

    func userMessage(using l10n: L10n) -> String {
        switch (self, l10n.language) {
        case (.adNotReady, .korean):
            return "광고를 준비하지 못했어요. 잠시 후 다시 시도해주세요."
        case (.adNotReady, .english):
            return "Ad is not ready. Please try again shortly."
        case (.presentationFailed, .korean):
            return "광고 재생에 실패했어요."
        case (.presentationFailed, .english):
            return "Failed to play the ad."
        case (.rewardNotEarned, .korean):
            return "광고를 끝까지 시청해야 저장할 수 있어요."
        case (.rewardNotEarned, .english):
            return "Please watch the full ad to save."
        }
    }
}

protocol RewardedAdService: AnyObject {
    var isAdReady: Bool { get }
    func loadAd() async
    // Returns true if the reward was earned (user watched the full ad).
    func showAd() async throws -> Bool
}

// MARK: - AdMob production implementation

#if canImport(GoogleMobileAds)

final class AdMobRewardedAdService: NSObject, RewardedAdService {
    #if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/5224354917"
    #else
    private static let adUnitID = "ca-app-pub-9549021857234311/1031203180"
    #endif

    private var rewardedAd: GADRewardedAd?
    var isAdReady: Bool { rewardedAd != nil }

    func loadAd() async {
        do {
            rewardedAd = try await GADRewardedAd.load(
                withAdUnitID: Self.adUnitID,
                request: GADRequest()
            )
        } catch {
            rewardedAd = nil
        }
    }

    func showAd() async throws -> Bool {
        guard let ad = rewardedAd else {
            throw RewardedAdError.adNotReady
        }
        guard let rootVC = UIApplication.rootViewController else {
            throw RewardedAdError.adNotReady
        }

        let presenter = RewardedAdPresenter()
        let earned = try await presenter.present(ad, from: rootVC)
        rewardedAd = nil
        Task { await loadAd() } // preload next
        return earned
    }
}

private final class RewardedAdPresenter: NSObject, GADFullScreenContentDelegate {
    private var continuation: CheckedContinuation<Bool, Error>?
    private var rewardEarned = false

    func present(_ ad: GADRewardedAd, from viewController: UIViewController) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            ad.fullScreenContentDelegate = self
            ad.present(fromRootViewController: viewController) {
                self.rewardEarned = true
            }
        }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        continuation?.resume(returning: rewardEarned)
        continuation = nil
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        continuation?.resume(throwing: RewardedAdError.presentationFailed(error))
        continuation = nil
    }
}

#endif // canImport(GoogleMobileAds)

// MARK: - No-op (used when SDK is absent or in UI tests)

final class NoOpRewardedAdService: RewardedAdService {
    var isAdReady: Bool { true }
    func loadAd() async {}
    // Always returns true — no real ad shown.
    func showAd() async throws -> Bool { true }
}

// MARK: - Helpers

private extension UIApplication {
    static var rootViewController: UIViewController? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
    }
}
