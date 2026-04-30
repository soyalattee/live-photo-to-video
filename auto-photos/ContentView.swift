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

    private var activeTheme: TemplateTheme {
        viewModel.selectedTemplate?.theme ?? TemplateCatalog.templates[0].theme
    }

    var body: some View {
        ZStack {
            AtmosphericBackgroundView(theme: activeTheme)
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
        VStack(alignment: .leading, spacing: 18) {
            Text("Template-Driven\nLive Photo Studio")
                .font(.custom("AvenirNextCondensed-Bold", size: 38))
                .foregroundStyle(.white)
                .lineSpacing(-2)

            Text("템플릿을 고르고, 사진 순서를 드래그로 다듬고, BGM과 텍스트 포함 여부까지 선택해서 세로형 숏폼을 완성해보세요.")
                .font(.custom("AvenirNext-Medium", size: 16))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                InfoPillView(title: "Template First", systemImage: "square.grid.2x2.fill")
                InfoPillView(title: "Drag Reorder", systemImage: "hand.draw.fill")
                InfoPillView(title: "9:16 MP4", systemImage: "rectangle.portrait.fill")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
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
                .foregroundStyle(.white)

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
                        .foregroundStyle(.white)

                    Text(template.description)
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundStyle(Color.white.opacity(0.78))

                    HStack(spacing: 10) {
                        MetricPillView(label: summary)
                        MetricPillView(label: estimatedDurationText)
                    }

                    Text("기본 선택 순서가 그대로 들어가 있고, 길게 눌러 드래그하면 순서를 바꿀 수 있어요.")
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundStyle(Color.white.opacity(0.66))

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.custom("AvenirNext-DemiBold", size: 14))
                            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.55))
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
                    .tint(.white)
                    .scaleEffect(1.6)

                Text(step.title)
                    .font(.custom("AvenirNextCondensed-Bold", size: 30))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("generation.statusText")

                Text(step.subtitle)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .multilineTextAlignment(.center)

                Text("\(templateName) 템플릿에 \(count)개의 장면을 배치하고 있어요.")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundStyle(Color.white.opacity(0.66))

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
                .foregroundStyle(.white)

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
                                .foregroundStyle(.white)

                            Text("미리보기는 현재 템플릿 기본 옵션으로 생성된 완성본이에요. 저장이나 공유할 때는 아래 옵션으로 BGM과 텍스트 포함 여부를 바꿀 수 있어요.")
                                .font(.custom("AvenirNext-Medium", size: 14))
                                .foregroundStyle(Color.white.opacity(0.72))
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
                            .foregroundStyle(Color.white.opacity(0.62))
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.custom("AvenirNext-DemiBold", size: 14))
                            .foregroundStyle(Color(red: 0.74, green: 0.96, blue: 0.77))
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
                    .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.35))

                Text("문제가 생겼어요")
                    .font(.custom("AvenirNextCondensed-Bold", size: 28))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundStyle(Color.white.opacity(0.72))

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
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)

                Text("선택한 사진을 템플릿에 맞게 준비하는 중이에요.")
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.56))
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
                            .foregroundStyle(.white)

                        Spacer(minLength: 0)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(template.theme.secondaryAccent.color)
                        }
                    }

                    Text(template.tagline)
                        .font(.custom("AvenirNext-DemiBold", size: 14))
                        .foregroundStyle(template.theme.secondaryAccent.color)

                    Text(template.description)
                        .font(.custom("AvenirNext-Medium", size: 14))
                        .foregroundStyle(Color.white.opacity(0.72))

                    HStack(spacing: 8) {
                        MetricPillView(label: template.selectionCaption)
                        MetricPillView(label: String(format: "%.1fs", template.totalDuration))
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.16 : 0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                isSelected ? template.theme.secondaryAccent.color.opacity(0.7) : .white.opacity(0.12),
                                lineWidth: 1.2
                            )
                    )
            )
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
                        .foregroundStyle(Color.white.opacity(0.64))

                    Text(template.name)
                        .font(.custom("AvenirNextCondensed-Bold", size: 28))
                        .foregroundStyle(.white)

                    Text(template.selectionCaption)
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundStyle(Color.white.opacity(0.76))
                } else {
                    Text("아직 템플릿이 선택되지 않았어요.")
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundStyle(Color.white.opacity(0.76))
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
                .foregroundStyle(.white)

            Text(item.kind == .livePhoto ? "Live Photo" : "Photo")
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
        )
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
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.custom("AvenirNext-Medium", size: 13))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .disabled(!isEnabled)
            .tint(Color(red: 0.95, green: 0.63, blue: 0.35))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.16))
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
                    .fill(.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
            )
    }
}

private struct MetricPillView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12), in: Capsule())
    }
}

private struct InfoPillView: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.12), in: Capsule())
    }
}

private struct AtmosphericBackgroundView: View {
    let theme: TemplateTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundTop.color, theme.backgroundBottom.color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(theme.accent.color.opacity(0.28))
                .frame(width: 320, height: 320)
                .blur(radius: 18)
                .offset(x: 120, y: -260)

            Circle()
                .fill(theme.secondaryAccent.color.opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 28)
                .offset(x: -150, y: 260)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.03), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
            .foregroundStyle(Color.black.opacity(0.8))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.79, blue: 0.43),
                                Color(red: 0.94, green: 0.56, blue: 0.31),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.2), radius: 18, y: 10)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-DemiBold", size: 16))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.12 : 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}
