import SwiftUI
import UniformTypeIdentifiers

struct MediaSequenceScreen: View {
    let l10n: L10n
    let template: VideoTemplate
    @Binding var cinematicTextCustomization: TemplateCinematicTextCustomization?
    let items: [SelectedMediaItem]
    let summary: String
    let estimatedDurationText: String
    let validationMessage: String?
    let canGenerate: Bool
    let onMoveItem: (SelectedMediaItem, SelectedMediaItem) -> Void
    let onDeleteItem: (SelectedMediaItem) -> Void
    let onGenerate: () -> Void
    let onReselect: () -> Void
    let onReset: () -> Void

    @State private var draggedItem: SelectedMediaItem?

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    textSection
                    sequenceSection
                    actionSection
                }
                .padding(.horizontal, LocketTheme.pagePadding)
                .padding(.top, 92)
                .padding(.bottom, 40)
            }

            VStack(spacing: 0) {
                LocketTopBar(title: l10n.appName, showsBackButton: true, onBack: onReset)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var textSection: some View {
        if let binding = customizationBinding {
            VStack(alignment: .leading, spacing: 18) {
                if
                    let previewItem = items.first,
                    let previewIntro = template.resolvedCinematicIntro(customization: binding.wrappedValue)
                {
                    TemplateTextPreviewCard(
                        title: l10n.textStylePreview,
                        image: previewItem.thumbnail,
                        intro: previewIntro
                    )
                }

                if template.lockScreenOverlay != nil {
                    LocketInputField(label: l10n.bottomCaptionLabel, text: binding.secondaryText, axis: .vertical)
                } else {
                    LocketInputField(label: l10n.titleLabel, text: binding.primaryText, axis: .vertical)
                    LocketInputField(label: l10n.shortSentenceLabel, text: binding.secondaryText, axis: .vertical)
                }

                TemplateTextColorControls(
                    textColor: colorBinding(
                        for: binding,
                        keyPath: \.textColor
                    ),
                    outlineColor: colorBinding(
                        for: binding,
                        keyPath: \.shadowColor
                    ),
                    textColorLabel: l10n.textFillColor,
                    outlineColorLabel: l10n.textOutlineColor
                )
            }
        } else {
            EmptyView()
        }
    }

    private var sequenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                Text(l10n.mediaSequence)
                    .font(LocketTheme.sans(20, weight: .semibold))
                    .foregroundStyle(LocketTheme.ink)
                Spacer()
                Text(summary)
                    .font(LocketTheme.sans(12, weight: .semibold))
                    .foregroundStyle(LocketTheme.inkSoft)
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    LocketSequenceRow(
                        item: item,
                        l10n: l10n,
                        clipDurationText: clipDurationText(for: item)
                    ) {
                        onDeleteItem(item)
                    }
                    .onDrag {
                        draggedItem = item
                        return NSItemProvider(object: NSString(string: item.id.uuidString))
                    }
                    .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(targetItem: item, draggedItem: $draggedItem, onMoveItem: onMoveItem))
                }

                Button(action: onReselect) {
                    Label(l10n.reselectMedia, systemImage: "plus")
                        .font(LocketTheme.sans(12, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color(hex: 0xA83255))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LocketTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LocketTheme.roseBorder, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(estimatedDurationText)
                .font(LocketTheme.sans(12, weight: .semibold))
                .foregroundStyle(LocketTheme.inkSoft)

            if let validationMessage {
                Text(validationMessage)
                    .font(LocketTheme.sans(14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xA83255))
                    .accessibilityIdentifier("selection.validationText")
            }

            Button(action: onGenerate) {
                Label(l10n.generateVideo, systemImage: "movieclapper.fill")
            }
            .buttonStyle(LocketPrimaryButtonStyle())
            .opacity(canGenerate ? 1 : 0.50)
            .disabled(!canGenerate)
            .accessibilityIdentifier("selection.generateButton")
        }
    }

    private var customizationBinding: Binding<TemplateCinematicTextCustomization>? {
        guard template.supportsCinematicTextCustomization else {
            return nil
        }

        return Binding(
            get: {
                cinematicTextCustomization ?? template.defaultCinematicTextCustomization ?? TemplateCinematicTextCustomization(
                    primaryText: "",
                    secondaryText: "",
                    primaryFontName: TemplateFontPreset.defaultPreset.fontName,
                    secondaryFontName: TemplateFontPreset.defaultPreset.fontName,
                    textColor: ColorToken(red: 1, green: 1, blue: 1),
                    shadowColor: ColorToken(red: 0, green: 0, blue: 0)
                )
            },
            set: { cinematicTextCustomization = $0 }
        )
    }

    private func colorBinding(
        for binding: Binding<TemplateCinematicTextCustomization>,
        keyPath: WritableKeyPath<TemplateCinematicTextCustomization, ColorToken>
    ) -> Binding<Color> {
        Binding(
            get: { binding.wrappedValue[keyPath: keyPath].color },
            set: { newColor in
                var updatedCustomization = binding.wrappedValue
                updatedCustomization[keyPath: keyPath] = ColorToken(color: newColor)
                binding.wrappedValue = updatedCustomization
            }
        )
    }

    private func clipDurationText(for item: SelectedMediaItem) -> String? {
        let durations = template.resolvedClipDurations(for: items.count)
        guard durations.indices.contains(item.selectionIndex) else {
            return nil
        }

        return formattedClipDuration(durations[item.selectionIndex])
    }

    private func formattedClipDuration(_ duration: TimeInterval) -> String {
        let roundedDuration = (duration * 10).rounded() / 10
        let text: String
        if roundedDuration.rounded() == roundedDuration {
            text = String(Int(roundedDuration))
        } else {
            text = String(format: "%.1f", roundedDuration)
        }

        return l10n.language == .korean ? "\(text)초" : "\(text)s"
    }
}

private struct TemplateTextPreviewCard: View {
    let title: String
    let image: UIImage
    let intro: TemplateCinematicIntroEffect

    private let renderSize = TemplateIntroRenderSupport.defaultRenderSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(LocketTheme.sans(12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: 0xA83255))

            Color.clear
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        let canvasFrame = CGRect(origin: .zero, size: geometry.size)
                        let scale = geometry.size.width / renderSize.width

                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: canvasFrame.width, height: canvasFrame.height)
                                .clipped()

                            ForEach(Array(previewTextLayouts.enumerated()), id: \.offset) { _, layout in
                                PreviewTextOverlay(
                                    layout: layout,
                                    scale: scale
                                )
                            }

                            ForEach(Array(intro.icons.enumerated()), id: \.offset) { _, icon in
                                PreviewIntroIcon(icon: icon, scale: scale)
                            }
                        }
                        .frame(width: canvasFrame.width, height: canvasFrame.height)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(LocketTheme.roseBorder.opacity(0.40), lineWidth: 1)
                )
                .padding(.horizontal, 34)
        }
    }

    private var previewTextLayouts: [TemplateIntroRenderedTextOverlay] {
        TemplateIntroRenderSupport.textLayouts(
            for: intro.textOverlays,
            renderSize: renderSize
        )
    }
}

private struct PreviewTextOverlay: View {
    let layout: TemplateIntroRenderedTextOverlay
    let scale: CGFloat

    var body: some View {
        if let image = layout.image {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .frame(
                    width: layout.frame.width * scale,
                    height: layout.frame.height * scale
                )
                .position(
                    x: layout.frame.midX * scale,
                    y: layout.frame.midY * scale
                )
        }
    }
}

private struct PreviewIntroIcon: View {
    let icon: TemplateIntroIcon
    let scale: CGFloat

    var body: some View {
        if let image = icon.image {
            let frame = TemplateIntroRenderSupport.iconFrame(for: icon)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: frame.width * scale,
                    height: frame.height * scale
                )
                .position(
                    x: frame.midX * scale,
                    y: frame.midY * scale
                )
        }
    }
}

private struct TemplateTextColorControls: View {
    @Binding var textColor: Color
    @Binding var outlineColor: Color
    let textColorLabel: String
    let outlineColorLabel: String

    var body: some View {
        HStack(spacing: 12) {
            TemplateColorPicker(label: textColorLabel, color: $textColor)
            TemplateColorPicker(label: outlineColorLabel, color: $outlineColor)
        }
    }
}

private struct TemplateColorPicker: View {
    let label: String
    @Binding var color: Color

    var body: some View {
        ColorPicker(selection: $color, supportsOpacity: false) {
            Text(label)
                .font(LocketTheme.sans(12, weight: .bold))
                .foregroundStyle(LocketTheme.ink)
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(LocketTheme.roseBorder.opacity(0.30), lineWidth: 1)
        )
    }
}

private extension TemplateIntroIcon {
    var image: UIImage? {
        guard let assetURL = imageAsset.assetURL else {
            return nil
        }

        return UIImage(contentsOfFile: assetURL.path)
    }
}
