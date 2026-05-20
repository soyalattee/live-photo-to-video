//
//  ContentView.swift
//  auto-photos
//
//  Created by 박소연 on 4/19/26.
//

import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel: AutoPhotosViewModel
    @State private var isPickerPresented = false
    private let l10n = L10n()

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
            screenContent

            if viewModel.isResolvingSelection {
                LocketLoadingOverlay(l10n: l10n)
            }
        }
        .alert(item: $viewModel.alertInfo) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(l10n.language == .korean ? "확인" : "OK"))
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
    private var screenContent: some View {
        switch viewModel.generationState {
        case .idle:
            TemplateGalleryScreen(
                l10n: l10n,
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
                MediaSequenceScreen(
                    l10n: l10n,
                    template: selectedTemplate,
                    cinematicTextCustomization: $viewModel.cinematicTextCustomization,
                    items: viewModel.selectedItems,
                    summary: viewModel.localizedSelectionSummary(using: l10n),
                    estimatedDurationText: viewModel.localizedEstimatedDurationText(using: l10n),
                    validationMessage: viewModel.validationMessage,
                    canGenerate: viewModel.canGenerate,
                    onMoveItem: viewModel.moveItem,
                    onMoveItemToEnd: viewModel.moveItemToEnd,
                    onDeleteItem: viewModel.removeItem,
                    onGenerate: viewModel.startGeneration,
                    onReselect: {
                        isPickerPresented = true
                    },
                    onReset: viewModel.resetToHome
                )
            }
        case let .generating(step):
            LocketGeneratingScreen(
                l10n: l10n,
                step: step,
                templateName: viewModel.selectedTemplate?.name ?? l10n.selectedTemplate,
                selectedItemCount: viewModel.selectedItems.count,
                onCancel: viewModel.cancelGeneration
            )
        case let .preview(video):
            if let selectedTemplate = viewModel.selectedTemplate {
                VideoPreviewScreen(
                    l10n: l10n,
                    template: selectedTemplate,
                    video: video,
                    exportOptions: viewModel.exportOptions,
                    statusMessage: viewModel.toastMessage,
                    note: viewModel.localizedExportSectionNote(using: l10n),
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
            LocketErrorScreen(
                l10n: l10n,
                message: message,
                onTryAgain: viewModel.recoverFromError,
                onStartOver: viewModel.resetToHome
            )
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
        configuration.filter = .any(of: [.images, .livePhotos, .videos])

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

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ReorderDropDelegate: DropDelegate {
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
