import SwiftUI

struct LocketGeneratingScreen: View {
    let l10n: L10n
    let step: GenerationStep
    let templateName: String
    let selectedItemCount: Int
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(LocketTheme.accent)
                    .scaleEffect(1.7)
                    .accessibilityIdentifier("generation.progress")

                VStack(spacing: 10) {
                    Text(step.title(using: l10n))
                        .font(LocketTheme.serif(30, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LocketTheme.ink)
                        .accessibilityIdentifier("generation.statusText")

                    Text(step.subtitle(using: l10n))
                        .font(LocketTheme.sans(15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LocketTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 6) {
                    Text(templateName)
                        .font(LocketTheme.sans(14, weight: .bold))
                        .foregroundStyle(LocketTheme.accent)

                    Text(itemCountText)
                        .font(LocketTheme.sans(13, weight: .semibold))
                        .foregroundStyle(LocketTheme.inkSoft)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous)
                        .stroke(LocketTheme.roseBorder.opacity(0.35))
                )

                Button(l10n.cancel, action: onCancel)
                    .buttonStyle(LocketSecondaryButtonStyle())
                    .frame(maxWidth: 260)
                    .accessibilityIdentifier("generation.cancelButton")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, LocketTheme.pagePadding)
        }
    }

    private var itemCountText: String {
        if l10n.language == .korean {
            return "\(selectedItemCount)개 미디어 선택됨"
        }

        let unit = selectedItemCount == 1 ? "item" : "items"
        return "\(selectedItemCount) \(unit) selected"
    }
}

struct LocketErrorScreen: View {
    let l10n: L10n
    let message: String
    let onTryAgain: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(LocketTheme.accent)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(l10n.errorTitle)
                        .font(LocketTheme.serif(30, weight: .bold))
                        .foregroundStyle(LocketTheme.ink)

                    Text(message)
                        .font(LocketTheme.sans(15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LocketTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button(l10n.tryAgain, action: onTryAgain)
                        .buttonStyle(LocketPrimaryButtonStyle())
                        .accessibilityIdentifier("error.retryButton")

                    Button(l10n.startOver, action: onStartOver)
                        .buttonStyle(LocketSecondaryButtonStyle())
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, LocketTheme.pagePadding)
        }
    }
}

struct LocketLoadingOverlay: View {
    let l10n: L10n

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(LocketTheme.accent)

                Text(l10n.mediaLoading)
                    .font(LocketTheme.sans(14, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LocketTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(Color.white, in: RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous)
                    .stroke(LocketTheme.roseBorder.opacity(0.35))
            )
            .shadow(color: LocketTheme.shadow, radius: 18, y: 10)
            .padding(.horizontal, LocketTheme.pagePadding)
        }
    }
}
