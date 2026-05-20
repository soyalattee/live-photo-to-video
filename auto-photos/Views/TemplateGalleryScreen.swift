import SwiftUI

struct TemplateGalleryScreen: View {
    let l10n: L10n
    let templates: [VideoTemplate]
    let selectedTemplate: VideoTemplate?
    let canOpenPicker: Bool
    let onSelectTemplate: (VideoTemplate) -> Void
    let onOpenPicker: () -> Void

    var body: some View {
        ZStack {
            LocketTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.templateGalleryHeadlinePrefix)
                            .font(LocketTheme.serif(28, weight: .bold))
                            .foregroundStyle(LocketTheme.ink)
                        HStack(spacing: 6) {
                            Text(l10n.templateGalleryHeadlineAccent)
                                .foregroundStyle(LocketTheme.accent)
                            Text(l10n.templateGalleryHeadlineSuffix)
                                .foregroundStyle(LocketTheme.ink)
                        }
                        .font(LocketTheme.serif(28, weight: .bold))
                        Text(l10n.templateGallerySubtitle)
                            .font(LocketTheme.serif(16))
                            .foregroundStyle(LocketTheme.inkSoft)
                    }
                    .padding(.top, 96)
                    .padding(.horizontal, LocketTheme.pagePadding)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(templates) { template in
                            LocketTemplateCard(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id,
                                onSelect: { onSelectTemplate(template) }
                            )
                        }
                    }
                    .padding(.horizontal, LocketTheme.pagePadding)
                    .padding(.bottom, 128)
                }
            }

            VStack(spacing: 0) {
                LocketTopBar(title: l10n.appName)
                Spacer()
            }

            LocketBottomActionBar {
                Button(action: onOpenPicker) {
                    Label(selectedTemplate == nil ? l10n.chooseTemplateFirst : l10n.chooseMedia, systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(LocketPrimaryButtonStyle())
                .opacity(canOpenPicker ? 1 : 0.50)
                .disabled(!canOpenPicker)
                .accessibilityIdentifier("home.makeVideoButton")
            }
        }
    }
}
