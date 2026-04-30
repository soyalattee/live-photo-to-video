//
//  ContentView.swift
//  auto-photos
//
//  Created by 박소연 on 4/19/26.
//

import AVKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel: AutoPhotosViewModel
    @State private var isPickerPresented = false

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: AppBootstrap.makeViewModel())
    }

    @MainActor
    init(viewModel: AutoPhotosViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            AtmosphericBackgroundView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    headerSection
                    contentSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }

            if viewModel.isResolvingSelection {
                LoadingOverlayView()
            }
        }
        .alert(item: $viewModel.alertInfo) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("확인"))
            )
        }
        .sheet(isPresented: $isPickerPresented) {
            MediaPickerSheet(selectionLimit: viewModel.pickerSelectionLimit) { results in
                Task {
                    await viewModel.handlePickerResults(results)
                }
            }
            .id(viewModel.pickerResetToken)
        }
        .sheet(item: $viewModel.shareSheetPayload, onDismiss: viewModel.dismissShareSheet) { payload in
            ShareSheetView(items: [payload.url])
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.generationState {
        case .idle:
            HomeStateView(
                templates: viewModel.templates,
                selectedTemplate: viewModel.selectedTemplate,
                canOpenPicker: viewModel.canOpenPicker,
                onSelectTemplate: viewModel.selectTemplate,
                onOpenPicker: {
                    isPickerPresented = true
                }
            )
        case .selectionReview:
            if let selectedTemplate = viewModel.selectedTemplate {
                SelectionReviewView(
                    template: selectedTemplate,
                    items: viewModel.selectedItems,
                    summary: viewModel.selectionSummary,
                    estimatedDurationText: viewModel.estimatedDurationText,
                    validationMessage: viewModel.validationMessage,
                    canGenerate: viewModel.canGenerate,
                    onMoveItem: viewModel.moveItem,
                    onGenerate: viewModel.startGeneration,
                    onReselect: {
                        isPickerPresented = true
                    },
                    onReset: viewModel.resetToHome
                )
            }
        case let .generating(step):
            GeneratingStateView(
                step: step,
                templateName: viewModel.selectedTemplate?.name ?? "Template",
                count: viewModel.selectedItems.count,
                onCancel: viewModel.cancelGeneration
            )
        case let .preview(video):
            if let selectedTemplate = viewModel.selectedTemplate {
                PreviewStateView(
                    template: selectedTemplate,
                    video: video,
                    exportOptions: viewModel.exportOptions,
                    statusMessage: viewModel.toastMessage,
                    note: viewModel.exportSectionNote,
                    isSaving: viewModel.isSaving,
                    isSharing: viewModel.isSharing,
                    onToggleMusic: viewModel.updateExportMusicOption,
                    onToggleText: viewModel.updateExportTextOption,
                    onSave: {
                        Task {
                            await viewModel.saveGeneratedVideo()
                        }
                    },
                    onShare: {
                        Task {
                            await viewModel.prepareShareVideo()
                        }
                    },
                    onRetry: viewModel.returnToSelectionReview,
                    onReset: viewModel.resetToHome
                )
            }
        case let .error(message):
            ErrorStateView(
                message: message,
                onRecover: viewModel.recoverFromError,
                onReset: viewModel.resetToHome
            )
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 20) {
            BrandLogoView(size: 96)

            VStack(alignment: .leading, spacing: 14) {
                Text("Template-Driven\nLive Photo Studio")
                    .font(.custom("AvenirNextCondensed-Bold", size: 36))
                    .foregroundStyle(BrandPalette.ink)
                    .lineSpacing(-2)

                Text("로고의 무드처럼 깔끔하고 부드러운 톤으로, 사진을 골라 순서를 다듬고 감도 있게 숏폼으로 완성해보세요.")
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundStyle(BrandPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    InfoPillView(title: "Template First", systemImage: "square.grid.2x2.fill")
                    InfoPillView(title: "Drag Reorder", systemImage: "hand.draw.fill")
                    InfoPillView(title: "9:16 MP4", systemImage: "rectangle.portrait.fill")
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(BrandPalette.ivory.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(BrandPalette.line, lineWidth: 1)
                )
        )
        .shadow(color: BrandPalette.shadow, radius: 24, y: 14)
    }
}

private struct HomeStateView: View {
    let templates: [VideoTemplate]
    let selectedTemplate: VideoTemplate?
    let canOpenPicker: Bool
    let onSelectTemplate: (VideoTemplate) -> Void
    let onOpenPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("템플릿 선택")
                .font(.custom("AvenirNextCondensed-DemiBold", size: 28))
                .foregroundStyle(BrandPalette.ink)

            VStack(spacing: 14) {
                ForEach(templates) { template in
                    TemplateCardView(
                        template: template,
                        isSelected: selectedTemplate?.id == template.id,
                        onSelect: {
                            onSelectTemplate(template)
                        }
                    )
                }
            }

            TemplateActionPanelView(
                template: selectedTemplate,
                isButtonEnabled: selectedTemplate != nil && canOpenPicker,
                onOpenPicker: onOpenPicker
            )
        }
    }
}

private struct SelectionReviewView: View {
    let template: VideoTemplate
    let items: [SelectedMediaItem]
    let summary: String
    let estimatedDurationText: String
    let validationMessage: String?
    let canGenerate: Bool
    let onMoveItem: (SelectedMediaItem, SelectedMediaItem) -> Void
    let onGenerate: () -> Void
    let onReselect: () -> Void
    let onReset: () -> Void

    @State private var draggedItem: SelectedMediaItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassPanelView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(template.name)
                        .font(.custom("AvenirNextCondensed-DemiBold", size: 28))
                        .foregroundStyle(BrandPalette.ink)

                    Text(template.description)
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundStyle(BrandPalette.inkSoft)

                    HStack(spacing: 10) {
                        MetricPillView(label: summary)
                        MetricPillView(label: estimatedDurationText)
                    }

                    Text("기본 선택 순서가 그대로 들어가 있고, 길게 눌러 드래그하면 순서를 바꿀 수 있어요.")
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundStyle(BrandPalette.cocoa)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.custom("AvenirNext-DemiBold", size: 14))
                            .foregroundStyle(Color(red: 0.63, green: 0.34, blue: 0.27))
                            .accessibilityIdentifier("selection.validationText")
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        ReorderThumbnailCardView(item: item)
                            .onDrag {
                                draggedItem = item
                                return NSItemProvider(object: NSString(string: item.id.uuidString))
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: ReorderDropDelegate(
                                    targetItem: item,
                                    draggedItem: $draggedItem,
                                    onMoveItem: onMoveItem
                                )
                            )
                    }
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                Button(action: onReselect) {
                    Label("사진 다시 선택", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(action: onGenerate) {
                    Label("영상 생성", systemImage: "play.rectangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!canGenerate)
                .accessibilityIdentifier("selection.generateButton")
            }

            Button("처음으로", action: onReset)
                .buttonStyle(.plain)
                .font(.custom("AvenirNext-Medium", size: 15))
                .foregroundStyle(Color.white.opacity(0.74))
        }
    }
}

private struct MediaPickerSheet: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onComplete: ([PHPickerResult]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = selectionLimit
        configuration.filter = .any(of: [.images, .livePhotos])

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onComplete: ([PHPickerResult]) -> Void

        init(onComplete: @escaping ([PHPickerResult]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            onComplete(results)
        }
    }
}

private struct GeneratingStateView: View {
    let step: GenerationStep
    let templateName: String
    let count: Int
    let onCancel: () -> Void

    var body: some View {
        GlassPanelView {
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(BrandPalette.ink)
                    .scaleEffect(1.6)

                Text(step.title)
                    .font(.custom("AvenirNextCondensed-Bold", size: 30))
                    .foregroundStyle(BrandPalette.ink)
                    .accessibilityIdentifier("generation.statusText")

                Text(step.subtitle)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundStyle(BrandPalette.inkSoft)
                    .multilineTextAlignment(.center)

                Text("\(templateName) 템플릿에 \(count)개의 장면을 배치하고 있어요.")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundStyle(BrandPalette.cocoa)

                Button("취소", action: onCancel)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("generation.cancelButton")
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct PreviewStateView: View {
    let template: VideoTemplate
    let video: GeneratedVideo
    let exportOptions: VideoRenderOptions
    let statusMessage: String?
    let note: String?
    let isSaving: Bool
    let isSharing: Bool
    let onToggleMusic: (Bool) -> Void
    let onToggleText: (Bool) -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    let onRetry: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("미리보기")
                .font(.custom("AvenirNextCondensed-Bold", size: 30))
                .foregroundStyle(BrandPalette.ink)

            LoopingVideoPlayerView(url: video.url)
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            GlassPanelView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.name)
                                .font(.custom("AvenirNextCondensed-DemiBold", size: 24))
                                .foregroundStyle(BrandPalette.ink)

                            Text("미리보기는 현재 템플릿 기본 옵션으로 생성된 완성본이에요. 저장이나 공유할 때는 아래 옵션으로 BGM과 텍스트 포함 여부를 바꿀 수 있어요.")
                                .font(.custom("AvenirNext-Medium", size: 14))
                                .foregroundStyle(BrandPalette.inkSoft)
                        }

                        Spacer(minLength: 0)

                        MetricPillView(label: String(format: "%.1fs", video.duration))
                    }

                    ExportToggleCardView(
                        title: "노래 포함",
                        subtitle: template.isMusicAvailable
                            ? "템플릿 BGM을 영상 길이에 맞춰 자동 trim 또는 loop"
                            : (template.supportsMusic ? "BGM 파일 추가 후 자동 활성화" : "이 템플릿에는 노래가 없어요"),
                        systemImage: "music.note",
                        isOn: exportOptions.includesMusic,
                        isEnabled: template.isMusicAvailable,
                        onToggle: onToggleMusic
                    )

                    ExportToggleCardView(
                        title: "텍스트 포함",
                        subtitle: template.supportsText
                            ? "템플릿 오버레이 텍스트를 함께 출력"
                            : "이 템플릿에는 텍스트가 없어요",
                        systemImage: "character.cursor.ibeam",
                        isOn: exportOptions.includesText,
                        isEnabled: template.supportsText,
                        onToggle: onToggleText
                    )

                    if let note {
                        Text(note)
                            .font(.custom("AvenirNext-Medium", size: 13))
                            .foregroundStyle(BrandPalette.cocoa)
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.custom("AvenirNext-DemiBold", size: 14))
                            .foregroundStyle(Color(red: 0.31, green: 0.49, blue: 0.34))
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: onSave) {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("사진 앱에 저장", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isSaving || isSharing)
                .accessibilityIdentifier("preview.saveButton")

                Button(action: onShare) {
                    if isSharing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("파일 공유", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(isSaving || isSharing)
                .accessibilityIdentifier("preview.shareButton")
            }

            HStack(spacing: 12) {
                Button("순서 다시 보기", action: onRetry)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("preview.retryButton")

                Button("처음으로", action: onReset)
                    .buttonStyle(.plain)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundStyle(Color.white.opacity(0.74))
            }
        }
    }
}

private struct ErrorStateView: View {
    let message: String
    let onRecover: () -> Void
    let onReset: () -> Void

    var body: some View {
        GlassPanelView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color(red: 0.72, green: 0.46, blue: 0.28))

                Text("문제가 생겼어요")
                    .font(.custom("AvenirNextCondensed-Bold", size: 28))
                    .foregroundStyle(BrandPalette.ink)

                Text(message)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundStyle(BrandPalette.inkSoft)

                HStack(spacing: 12) {
                    Button("다시 시도", action: onRecover)
                        .buttonStyle(PrimaryActionButtonStyle())
                        .accessibilityIdentifier("error.retryButton")

                    Button("처음으로", action: onReset)
                        .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

private struct LoadingOverlayView: View {
    var body: some View {
        ZStack {
            BrandPalette.ink.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(BrandPalette.ink)

                Text("선택한 사진을 템플릿에 맞게 준비하는 중이에요.")
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundStyle(BrandPalette.ink)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(BrandPalette.ivory)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(BrandPalette.line, lineWidth: 1)
            )
        }
    }
}

private struct TemplateCardView: View {
    let template: VideoTemplate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [template.theme.accent.color, template.theme.secondaryAccent.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 112)
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(template.photoCount)")
                                .font(.custom("AvenirNextCondensed-Bold", size: 34))
                                .foregroundStyle(Color.black.opacity(0.75))
                            Text("PHOTOS")
                                .font(.custom("AvenirNext-Bold", size: 12))
                                .foregroundStyle(Color.black.opacity(0.58))
                        }
                        .padding(14),
                        alignment: .topLeading
                    )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(template.name)
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 26))
                            .foregroundStyle(BrandPalette.ink)

                        Spacer(minLength: 0)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(template.theme.secondaryAccent.color)
                        }
                    }

                    Text(template.tagline)
                        .font(.custom("AvenirNext-DemiBold", size: 14))
                        .foregroundStyle(BrandPalette.cocoa)

                    Text(template.description)
                        .font(.custom("AvenirNext-Medium", size: 14))
                        .foregroundStyle(BrandPalette.inkSoft)

                    HStack(spacing: 8) {
                        MetricPillView(label: template.selectionCaption)
                        MetricPillView(label: String(format: "%.1fs", template.totalDuration))
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(BrandPalette.ivory.opacity(isSelected ? 0.96 : 0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                isSelected ? BrandPalette.ink.opacity(0.25) : BrandPalette.line,
                                lineWidth: 1.2
                            )
                    )
            )
            .shadow(color: BrandPalette.shadow.opacity(isSelected ? 0.14 : 0.08), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.templateCard.\(template.id)")
    }
}

private struct TemplateActionPanelView: View {
    let template: VideoTemplate?
    let isButtonEnabled: Bool
    let onOpenPicker: () -> Void

    var body: some View {
        GlassPanelView {
            VStack(alignment: .leading, spacing: 14) {
                if let template {
                    Text("선택된 템플릿")
                        .font(.custom("AvenirNext-DemiBold", size: 14))
                        .foregroundStyle(BrandPalette.cocoa)

                    Text(template.name)
                        .font(.custom("AvenirNextCondensed-Bold", size: 28))
                        .foregroundStyle(BrandPalette.ink)

                    Text(template.selectionCaption)
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundStyle(BrandPalette.inkSoft)
                } else {
                    Text("아직 템플릿이 선택되지 않았어요.")
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundStyle(BrandPalette.inkSoft)
                }

                Button(action: onOpenPicker) {
                    Label(
                        template == nil ? "템플릿을 먼저 선택하세요" : "사진 추가하기",
                        systemImage: "sparkles.rectangle.stack.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!isButtonEnabled)
                .accessibilityIdentifier("home.makeVideoButton")
            }
        }
    }
}

private struct ReorderThumbnailCardView: View {
    let item: SelectedMediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(uiImage: item.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 184, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 13, weight: .bold))
                        .padding(10)
                        .background(.black.opacity(0.42), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(12)
                }

            Text(String(format: "%02d", item.selectionIndex + 1))
                .font(.custom("AvenirNextCondensed-Bold", size: 24))
                .foregroundStyle(BrandPalette.ink)

            Text(item.kind == .livePhoto ? "Live Photo" : "Photo")
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundStyle(BrandPalette.cocoa)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BrandPalette.ivory.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(BrandPalette.line, lineWidth: 1)
                )
        )
        .shadow(color: BrandPalette.shadow.opacity(0.08), radius: 16, y: 8)
    }
}

private struct ExportToggleCardView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isOn: Bool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(BrandPalette.ink)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BrandPalette.cream)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundStyle(BrandPalette.ink)

                Text(subtitle)
                    .font(.custom("AvenirNext-Medium", size: 13))
                    .foregroundStyle(BrandPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .disabled(!isEnabled)
            .tint(BrandPalette.ink)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BrandPalette.cream.opacity(0.82))
        )
    }
}

private struct GlassPanelView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(BrandPalette.ivory.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(BrandPalette.line, lineWidth: 1)
                    )
            )
            .shadow(color: BrandPalette.shadow.opacity(0.08), radius: 24, y: 12)
    }
}

private struct MetricPillView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .foregroundStyle(BrandPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BrandPalette.cream, in: Capsule())
    }
}

private struct InfoPillView: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .foregroundStyle(BrandPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(BrandPalette.cream, in: Capsule())
    }
}

private struct AtmosphericBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [BrandPalette.ivory, BrandPalette.cream],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(BrandPalette.sand.opacity(0.32))
                .frame(width: 360, height: 360)
                .blur(radius: 28)
                .offset(x: 180, y: -260)

            Circle()
                .fill(BrandPalette.ink.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 34)
                .offset(x: -170, y: 310)

            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BrandPalette.ivory.opacity(0.65), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 16)
                .offset(x: -110, y: -220)
        }
    }
}

private struct LoopingVideoPlayerView: View {
    let url: URL

    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .onAppear {
                let item = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: item)
                player.play()
            }
            .onDisappear {
                player.pause()
                player.replaceCurrentItem(with: nil)
            }
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ReorderDropDelegate: DropDelegate {
    let targetItem: SelectedMediaItem
    @Binding var draggedItem: SelectedMediaItem?
    let onMoveItem: (SelectedMediaItem, SelectedMediaItem) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem.id != targetItem.id else {
            return
        }

        onMoveItem(draggedItem, targetItem)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-DemiBold", size: 16))
            .foregroundStyle(BrandPalette.ivory)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BrandPalette.ink)
                    .shadow(color: BrandPalette.shadow.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 18, y: 10)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-DemiBold", size: 16))
            .foregroundStyle(BrandPalette.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BrandPalette.ivory.opacity(configuration.isPressed ? 0.96 : 0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(BrandPalette.line, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}
