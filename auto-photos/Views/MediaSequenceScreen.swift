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
    let onMoveItemToEnd: (SelectedMediaItem) -> Void
    let onDeleteItem: (SelectedMediaItem) -> Void
    let onGenerate: () -> Void
    let onReselect: () -> Void
    let onReset: () -> Void

    @State private var draggedItem: SelectedMediaItem?
    @State private var pendingDeleteItem: SelectedMediaItem?

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
        .alert(item: $pendingDeleteItem) { item in
            Alert(
                title: Text(l10n.language == .korean ? "미디어 제거" : "Remove Media"),
                message: Text(l10n.language == .korean ? "\(item.selectionIndex + 1)번째 미디어를 순서에서 제거할까요?" : "Remove media \(item.selectionIndex + 1) from the sequence?"),
                primaryButton: .destructive(Text(l10n.language == .korean ? "제거" : "Remove")) { onDeleteItem(item) },
                secondaryButton: .cancel(Text(l10n.cancel))
            )
        }
    }

    @ViewBuilder
    private var textSection: some View {
        if let binding = customizationBinding {
            VStack(alignment: .leading, spacing: 18) {
                if template.lockScreenOverlay != nil {
                    LocketInputField(label: l10n.bottomCaptionLabel, text: binding.secondaryText, axis: .vertical)
                } else {
                    LocketInputField(label: l10n.titleLabel, text: binding.primaryText, axis: .vertical)
                    LocketInputField(label: l10n.shortSentenceLabel, text: binding.secondaryText, axis: .vertical)
                }
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
                    LocketSequenceRow(item: item, l10n: l10n) {
                        pendingDeleteItem = item
                    }
                    .onDrag {
                        draggedItem = item
                        return NSItemProvider(object: NSString(string: item.id.uuidString))
                    }
                    .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(targetItem: item, draggedItem: $draggedItem, onMoveItem: onMoveItem))
                }

                if !items.isEmpty {
                    endDropTarget
                        .onDrop(
                            of: [UTType.text],
                            delegate: ReorderEndDropDelegate(
                                draggedItem: $draggedItem,
                                onMoveItemToEnd: onMoveItemToEnd
                            )
                        )
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

    private var endDropTarget: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.to.line.compact")
            Text(l10n.language == .korean ? "끝으로 놓기" : "Drop to end")
        }
        .font(LocketTheme.sans(12, weight: .bold))
        .tracking(0.3)
        .foregroundStyle(draggedItem == nil ? LocketTheme.inkSoft.opacity(0.55) : Color(hex: 0xA83255))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LocketTheme.surface.opacity(draggedItem == nil ? 0.45 : 1),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    draggedItem == nil ? LocketTheme.roseBorder.opacity(0.5) : Color(hex: 0xA83255),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        )
        .accessibilityIdentifier("selection.moveToEndDropTarget")
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
}

private struct ReorderEndDropDelegate: DropDelegate {
    @Binding var draggedItem: SelectedMediaItem?
    let onMoveItemToEnd: (SelectedMediaItem) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let draggedItem {
            onMoveItemToEnd(draggedItem)
        }

        draggedItem = nil
        return true
    }
}
