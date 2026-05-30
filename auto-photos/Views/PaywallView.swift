import SwiftUI

struct PaywallView: View {
    let l10n: L10n
    let isSubscribed: Bool
    let isPurchasing: Bool
    let isRestoring: Bool
    let onSubscribe: () async -> Void
    let onRestore: () async -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LocketTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    benefitsSection
                    footerSection
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LocketTheme.inkSoft)
                    .frame(width: 40, height: 40)
                    .background(LocketTheme.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, LocketTheme.pagePadding)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [LocketTheme.accent.opacity(0.18), LocketTheme.accent.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 12) {
                    BrandLogoView(size: 64)
                        .padding(.top, 56)

                    Text("PRO")
                        .font(LocketTheme.sans(11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(LocketTheme.accent, in: Capsule())

                    VStack(spacing: 6) {
                        Text(l10n.paywallTitle)
                            .font(LocketTheme.serif(28, weight: .bold))
                            .foregroundStyle(LocketTheme.ink)

                        Text(l10n.paywallSubtitle)
                            .font(LocketTheme.sans(15))
                            .foregroundStyle(LocketTheme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var benefitsSection: some View {
        VStack(spacing: 12) {
            PaywallBenefitRow(
                icon: "photo.stack.fill",
                title: l10n.paywallBenefit1Title,
                description: l10n.paywallBenefit1Description
            )
            PaywallBenefitRow(
                icon: "checkmark.seal.fill",
                title: l10n.paywallBenefit2Title,
                description: l10n.paywallBenefit2Description
            )
            PaywallBenefitRow(
                icon: "play.circle.fill",
                title: l10n.paywallBenefit3Title,
                description: l10n.paywallBenefit3Description
            )
        }
        .padding(LocketTheme.pagePadding)
    }

    private var footerSection: some View {
        VStack(spacing: 20) {
            Text(l10n.paywallPriceCaption)
                .font(LocketTheme.sans(13))
                .foregroundStyle(LocketTheme.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                Task { await onSubscribe() }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                } else {
                    Text(l10n.paywallSubscribeButton)
                        .font(LocketTheme.sans(16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
            }
            .background(
                LocketTheme.accent.opacity(isPurchasing ? 0.6 : 1),
                in: RoundedRectangle(cornerRadius: LocketTheme.controlRadius, style: .continuous)
            )
            .shadow(color: LocketTheme.accent.opacity(0.20), radius: 14, y: 8)
            .disabled(isPurchasing || isRestoring)

            Button {
                Task { await onRestore() }
            } label: {
                if isRestoring {
                    ProgressView()
                        .tint(LocketTheme.accent)
                } else {
                    Text(l10n.paywallRestoreButton)
                        .font(LocketTheme.sans(13, weight: .semibold))
                        .foregroundStyle(LocketTheme.accent)
                        .underline()
                }
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || isRestoring)
        }
        .padding(.horizontal, LocketTheme.pagePadding)
        .padding(.bottom, 48)
    }
}

private struct PaywallBenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LocketTheme.accent)
                .frame(width: 32, height: 32)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(LocketTheme.sans(15, weight: .bold))
                    .foregroundStyle(LocketTheme.ink)
                Text(description)
                    .font(LocketTheme.sans(13))
                    .foregroundStyle(LocketTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous)
                .stroke(LocketTheme.border, lineWidth: 1)
        )
    }
}
