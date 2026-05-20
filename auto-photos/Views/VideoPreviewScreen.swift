import AVKit
import SwiftUI

struct VideoPreviewScreen: View {
    let l10n: L10n
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

    private var musicEnabled: Bool {
        template.supportsMusic && template.isMusicAvailable
    }

    private var textEnabled: Bool {
        template.supportsText
    }

    private var isExportBusy: Bool {
        isSaving || isSharing
    }

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    preview
                    controls
                    actions
                }
                .padding(.horizontal, LocketTheme.pagePadding)
                .padding(.top, 92)
                .padding(.bottom, 40)
            }

            VStack(spacing: 0) {
                LocketTopBar(title: l10n.preview, showsBackButton: true, onBack: onRetry)
                Spacer()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.preview)
                .font(LocketTheme.serif(32, weight: .bold))
                .foregroundStyle(LocketTheme.ink)

            Text(template.name)
                .font(LocketTheme.sans(14, weight: .bold))
                .foregroundStyle(LocketTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(LocketTheme.roseBorder.opacity(0.45)))
        }
    }

    private var preview: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width * 16.0 / 9.0

            LoopingVideoPlayerView(url: video.url)
                .frame(width: width, height: height)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: LocketTheme.previewRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LocketTheme.previewRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.70), lineWidth: 2)
                )
                .shadow(color: LocketTheme.shadow, radius: 22, y: 12)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .accessibilityIdentifier("preview.videoPlayer")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LocketToggleCard(
                    title: l10n.musicOn,
                    systemImage: "music.note",
                    isOn: exportOptions.includesMusic && musicEnabled,
                    isEnabled: musicEnabled,
                    onToggle: onToggleMusic
                )

                LocketToggleCard(
                    title: l10n.textOn,
                    systemImage: "textformat",
                    isOn: exportOptions.includesText && textEnabled,
                    isEnabled: textEnabled,
                    onToggle: onToggleText
                )
            }

            if let note {
                Text(note)
                    .font(LocketTheme.sans(13, weight: .semibold))
                    .foregroundStyle(LocketTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(LocketTheme.sans(13, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2D7A45))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("preview.statusMessage")
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LocketTheme.cardRadius, style: .continuous)
                .stroke(LocketTheme.roseBorder.opacity(0.35))
        )
    }

    private var actions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onSave) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label(l10n.saveToCameraRoll, systemImage: "square.and.arrow.down.fill")
                    }
                }
                .buttonStyle(LocketPrimaryButtonStyle())
                .opacity(isExportBusy ? 0.55 : 1)
                .disabled(isExportBusy)
                .accessibilityIdentifier("preview.saveButton")

                Button(action: onShare) {
                    if isSharing {
                        ProgressView()
                            .tint(LocketTheme.ink)
                    } else {
                        Label(l10n.share, systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(LocketSecondaryButtonStyle())
                .opacity(isExportBusy ? 0.55 : 1)
                .disabled(isExportBusy)
                .accessibilityIdentifier("preview.shareButton")
            }

            HStack(spacing: 12) {
                Button(l10n.retrySequence, action: onRetry)
                    .buttonStyle(LocketSecondaryButtonStyle())
                    .accessibilityIdentifier("preview.retryButton")

                Button(l10n.startOver, action: onReset)
                    .buttonStyle(LocketSecondaryButtonStyle())
            }
        }
    }
}

struct LoopingVideoPlayerView: View {
    let url: URL

    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .onAppear {
                let item = AVPlayerItem(url: url)
                looper = AVPlayerLooper(player: player, templateItem: item)
                player.play()
            }
            .onDisappear {
                player.pause()
                player.removeAllItems()
                looper = nil
            }
    }
}
