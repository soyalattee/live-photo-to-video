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
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.93, blue: 0.90), Color(red: 0.89, green: 0.94, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    contentSection
                }
                .padding(20)
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
            MediaPickerSheet { results in
                Task {
                    await viewModel.handlePickerResults(results)
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.generationState {
        case .idle:
            HomeStateView {
                isPickerPresented = true
            }
        case .selectionReview:
            SelectionReviewView(
                items: viewModel.selectedItems,
                summary: viewModel.selectionSummary,
                estimatedDurationText: viewModel.estimatedDurationText,
                validationMessage: viewModel.validationMessage,
                canGenerate: viewModel.canGenerate,
                onGenerate: viewModel.startGeneration,
                onReselect: {
                    isPickerPresented = true
                },
                onReset: viewModel.resetToHome
            )
        case let .generating(step):
            GeneratingStateView(
                step: step,
                count: viewModel.selectedItems.count,
                onCancel: viewModel.cancelGeneration
            )
        case let .preview(video):
            PreviewStateView(
                video: video,
                isSaving: viewModel.isSaving,
                statusMessage: viewModel.toastMessage,
                onSave: {
                    Task {
                        await viewModel.saveGeneratedVideo()
                    }
                },
                onRetry: viewModel.returnToSelectionReview,
                onReset: viewModel.resetToHome
            )
        case let .error(message):
            ErrorStateView(
                message: message,
                onRecover: viewModel.recoverFromError,
                onReset: viewModel.resetToHome
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Live Photo Short Video Creator")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))

            Text("사진과 Live Photo를 골라서 세로형 쇼츠 영상으로 빠르게 합쳐보세요.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TagView(title: "iPhone", systemImage: "iphone")
                TagView(title: "9:16 MP4", systemImage: "rectangle.portrait")
                TagView(title: "무음 MVP", systemImage: "speaker.slash")
            }
        }
    }
}

private struct HomeStateView: View {
    let onOpenPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FeatureCardView(
                title: "한 번에 3~30장 선택",
                description: "사진과 Live Photo를 섞어서 골라도 순서를 유지해 세로 영상으로 이어붙여요.",
                systemImage: "square.grid.2x2.fill"
            )

            FeatureCardView(
                title: "자동 세로 편집",
                description: "각 장면을 9:16 비율로 중앙 크롭해서 쇼츠용 프레임으로 맞춰요.",
                systemImage: "wand.and.stars"
            )

            FeatureCardView(
                title: "바로 저장과 공유",
                description: "생성된 MP4를 사진 앱에 저장하고 필요한 경우 바로 공유할 수 있어요.",
                systemImage: "square.and.arrow.down"
            )

            Button(action: onOpenPicker) {
                Label("영상 만들기", systemImage: "sparkles.rectangle.stack.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityIdentifier("home.makeVideoButton")
        }
    }
}

private struct SelectionReviewView: View {
    let items: [SelectedMediaItem]
    let summary: String
    let estimatedDurationText: String
    let validationMessage: String?
    let canGenerate: Bool
    let onGenerate: () -> Void
    let onReselect: () -> Void
    let onReset: () -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))

                Text(estimatedDurationText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("selection.validationText")
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(items) { item in
                    SelectionThumbnailView(item: item)
                }
            }

            HStack(spacing: 12) {
                Button(action: onReselect) {
                    Label("다시 선택", systemImage: "photo.on.rectangle")
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
                .foregroundStyle(.secondary)
        }
    }
}

private struct MediaPickerSheet: UIViewControllerRepresentable {
    let onComplete: ([PHPickerResult]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = SelectionRules.maximumCount
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
    let count: Int
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(red: 0.17, green: 0.20, blue: 0.27))
                .scaleEffect(1.5)

            Text(step.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))
                .accessibilityIdentifier("generation.statusText")

            Text(step.subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("\(count)개의 장면을 준비하고 있어요.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Button("취소", action: onCancel)
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("generation.cancelButton")
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
    }
}

private struct PreviewStateView: View {
    let video: GeneratedVideo
    let isSaving: Bool
    let statusMessage: String?
    let onSave: () -> Void
    let onRetry: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("미리보기")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))

            LoopingVideoPlayerView(url: video.url)
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.green)
            }

            HStack(spacing: 12) {
                Button(action: onSave) {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("저장", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isSaving)
                .accessibilityIdentifier("preview.saveButton")

                ShareLink(item: video.url) {
                    Label("공유", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("preview.shareButton")
            }

            HStack(spacing: 12) {
                Button("다시 만들기", action: onRetry)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("preview.retryButton")

                Button("처음으로", action: onReset)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ErrorStateView: View {
    let message: String
    let onRecover: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color.orange)

            Text("문제가 생겼어요")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("다시 시도", action: onRecover)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("error.retryButton")

                Button("처음으로", action: onReset)
                    .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }
}

private struct LoadingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("선택한 사진을 정리하는 중이에요.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
        }
    }
}

private struct SelectionThumbnailView: View {
    let item: SelectedMediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(uiImage: item.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("#\(item.selectionIndex + 1)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))

            Text(item.kind == .livePhoto ? "Live Photo" : "Photo")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.85))
        )
    }
}

private struct FeatureCardView: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))

                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
    }
}

private struct TagView: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.8))
            )
            .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))
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

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.19, green: 0.24, blue: 0.34))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.17, green: 0.20, blue: 0.27))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
    }
}
