import SwiftUI

struct LocketTopBar: View {
    let title: String
    var showsBackButton = false
    var onBack: (() -> Void)?
    var onSettings: (() -> Void)? = nil

    var body: some View {
        HStack {
            if showsBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LocketTheme.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    BrandLogoView(size: 32)
                    Text(title)
                        .font(LocketTheme.serif(28, weight: .bold))
                        .tracking(-1.0)
                        .foregroundStyle(LocketTheme.ink)
                }
            }

            Spacer(minLength: 0)

            if showsBackButton {
                Text(title)
                    .font(LocketTheme.sans(20, weight: .heavy))
                    .tracking(-1.0)
                    .foregroundStyle(LocketTheme.ink)
                Spacer(minLength: 0)
            }

            if let onSettings {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(LocketTheme.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, LocketTheme.pagePadding)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.55))
    }
}

struct LocketBottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            content
                .padding(.horizontal, LocketTheme.pagePadding)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(LocketTheme.background.opacity(0.92).ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(LocketTheme.border)
                        .frame(height: 1)
                }
        }
    }
}

struct LocketPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LocketTheme.sans(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(LocketTheme.accent.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: LocketTheme.controlRadius, style: .continuous))
            .shadow(color: LocketTheme.accent.opacity(0.20), radius: 14, y: 8)
    }
}

struct LocketSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LocketTheme.sans(14, weight: .bold))
            .foregroundStyle(LocketTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: LocketTheme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LocketTheme.controlRadius, style: .continuous).stroke(LocketTheme.roseBorder, lineWidth: 2))
    }
}

struct LocketTemplateCard: View {
    let template: VideoTemplate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [template.theme.accent.color, template.theme.secondaryAccent.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(colors: [.clear, .black.opacity(0.80)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(LocketTheme.serif(18))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(template.tagline)
                        .font(LocketTheme.sans(11))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                }
                .padding(16)
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous)
                    .stroke(isSelected ? LocketTheme.accent : .clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.templateCard.\(template.id)")
    }
}

struct LocketInputField: View {
    let label: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(LocketTheme.sans(12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: 0xA83255))
            TextField(label, text: $text, axis: axis)
                .font(LocketTheme.sans(16, weight: .semibold))
                .foregroundStyle(LocketTheme.ink)
                .padding(.horizontal, 17)
                .padding(.vertical, 13)
                .background(LocketTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(LocketTheme.roseBorder.opacity(0.40)))
        }
    }
}

struct LocketSequenceRow: View {
    let item: SelectedMediaItem
    let l10n: L10n
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("\(item.selectionIndex + 1)")
                .font(LocketTheme.sans(12, weight: .bold))
                .foregroundStyle(LocketTheme.inkSoft)
                .frame(width: 18)

            Image(uiImage: item.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(l10n.language == .korean ? "\(item.selectionIndex + 1)번째 미디어" : "Media \(item.selectionIndex + 1)")
                    .font(LocketTheme.sans(14, weight: .medium))
                    .foregroundStyle(LocketTheme.ink)
                    .lineLimit(1)
                Text(item.kind.displayName(using: l10n))
                    .font(LocketTheme.sans(12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(LocketTheme.inkSoft)
            }

            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LocketTheme.inkSoft)
            }
            .buttonStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LocketTheme.inkSoft)
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LocketTheme.roseBorder.opacity(0.20)))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }
}

struct LocketToggleCard: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: { if isEnabled { onToggle(!isOn) } }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isOn ? LocketTheme.accent : LocketTheme.accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: isOn ? "checkmark" : systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isOn ? .white : LocketTheme.accent)
                    )
                Text(title)
                    .font(LocketTheme.sans(11, weight: .bold))
                    .foregroundStyle(LocketTheme.ink)
                Spacer(minLength: 0)

                Capsule()
                    .fill(isOn ? LocketTheme.accent : LocketTheme.roseBorder.opacity(0.42))
                    .frame(width: 42, height: 24)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .padding(3)
                            .shadow(color: Color.black.opacity(0.10), radius: 3, y: 1)
                    }
            }
            .padding(13)
            .background(
                (isOn ? LocketTheme.accent.opacity(0.08) : Color.white)
                    .opacity(isEnabled ? 1 : 0.56),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isOn ? LocketTheme.accent : LocketTheme.roseBorder.opacity(0.30), lineWidth: isOn ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isEnabled ? (isOn ? "On" : "Off") : (isOn ? "On, Unavailable" : "Off, Unavailable"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
