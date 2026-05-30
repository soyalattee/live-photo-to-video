import Foundation
import StoreKit

enum SubscriptionError: LocalizedError, Equatable {
    case productNotFound
    case purchasePending
    case userCancelled
    case verificationFailed

    var errorDescription: String? { userMessage(using: L10n()) }

    func userMessage(using l10n: L10n) -> String {
        switch (self, l10n.language) {
        case (.productNotFound, .korean):
            return "구독 상품을 불러오지 못했어요."
        case (.productNotFound, .english):
            return "Could not load the subscription product."
        case (.purchasePending, .korean):
            return "결제 승인 대기 중이에요. 잠시 후 다시 확인해주세요."
        case (.purchasePending, .english):
            return "Your purchase is pending approval. Please try again later."
        case (.userCancelled, .korean):
            return "결제가 취소되었어요."
        case (.userCancelled, .english):
            return "The purchase was cancelled."
        case (.verificationFailed, .korean):
            return "결제 검증에 실패했어요."
        case (.verificationFailed, .english):
            return "Purchase verification failed."
        }
    }
}

protocol SubscriptionService: AnyObject {
    // Always read from @MainActor context (via AutoPhotosViewModel).
    var isSubscribed: Bool { get }
    func startMonitoring(onStatusChange: @escaping @MainActor (Bool) -> Void)
    func purchase() async throws
    func restorePurchases() async throws
}

final class StoreKitSubscriptionService: SubscriptionService {
    static let weeklyProductID = "soya.auto-photos.weekly"

    // Written only from @MainActor Tasks; read only from @MainActor ViewModel.
    private(set) var isSubscribed = false

    func startMonitoring(onStatusChange: @escaping @MainActor (Bool) -> Void) {
        Task { @MainActor [weak self] in
            await self?.refreshAndNotify(onStatusChange)
        }
        Task { @MainActor [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshAndNotify(onStatusChange)
            }
        }
    }

    func purchase() async throws {
        let products = try await Product.products(for: [Self.weeklyProductID])
        guard let product = products.first else {
            throw SubscriptionError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.verificationFailed
            }
            await transaction.finish()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.purchasePending
        @unknown default:
            break
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshAndNotify { _ in }
    }

    @MainActor
    private func refreshAndNotify(_ onStatusChange: @escaping @MainActor (Bool) -> Void) async {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.weeklyProductID,
               tx.revocationDate == nil {
                subscribed = true
            }
        }
        let changed = isSubscribed != subscribed
        isSubscribed = subscribed
        if changed { onStatusChange(subscribed) }
    }
}

final class NoOpSubscriptionService: SubscriptionService {
    let isSubscribed = false
    func startMonitoring(onStatusChange: @escaping @MainActor (Bool) -> Void) {}
    func purchase() async throws {}
    func restorePurchases() async throws {}
}
