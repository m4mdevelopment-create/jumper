import SwiftUI

struct SettingsView: View {
    private static let privacyPolicyURL = URL(string: "https://steadyflowplayjumpingblock.com/privacy-policy.html")!
    private static let supportURL = URL(string: "https://steadyflowplayjumpingblock.com/support.html")!

    @Environment(DuperGameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.openURL) private var openURL
    @State private var isShowingResetConfirmation = false

    private var accent: Color {
        store.settings.accentStyle.primaryColor
    }

    private var shouldReduceMotion: Bool {
        store.settings.reducesMotion(systemReduceMotion: systemReduceMotion)
    }

    var body: some View {
        DuperScreen(
            title: "Settings",
            subtitle: "Feedback, style, and local data.",
            accent: accent
        ) {
            VStack(spacing: 12) {
                feedbackCard
                accentCard
                legalCard
                resetCard
            }
        }
        .alert("Reset Progress?", isPresented: $isShowingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Progress", role: .destructive) {
                store.resetLocalProgress()
            }
        } message: {
            Text("Clears local runs, achievements, and guide reads. Settings stay unchanged.")
        }
    }

    private var feedbackCard: some View {
        SettingsSection(title: "Feedback", accent: accent) {
            VStack(spacing: 0) {
                settingsToggle(
                    title: "Sound Effects",
                    subtitle: "Game sounds.",
                    keyPath: \.soundEnabled
                )

                SettingsDivider()

                settingsToggle(
                    title: "Haptics",
                    subtitle: "Tap feedback.",
                    keyPath: \.hapticsEnabled
                )

                SettingsDivider()

                settingsToggle(
                    title: "Reduced Motion",
                    subtitle: systemReduceMotion ? "System setting is on." : "Less movement.",
                    keyPath: \.reduceMotion
                )

                SettingsDivider()

                settingsToggle(
                    title: "High Contrast Meter",
                    subtitle: "Brighter meter fill.",
                    keyPath: \.highContrastMeter
                )
            }
        }
    }

    private var accentCard: some View {
        SettingsSection(title: "Accent Style", accent: accent) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(DuperAccentStyle.allCases) { style in
                    AccentStyleButton(
                        style: style,
                        isSelected: store.settings.accentStyle == style
                    ) {
                        store.updateSettings { settings in
                            settings.accentStyle = style
                        }
                    }
                }
            }
        }
    }

    private var resetCard: some View {
        SettingsSection(title: "Local Progress", accent: DJTheme.riskRed) {
            Text("Clears runs, achievements, and guide reads. Keeps settings.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(DJTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                isShowingResetConfirmation = true
            } label: {
                Label("Reset Local Progress", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(DuperButtonStyle(accent: DJTheme.riskRed, role: .danger, reduceMotion: shouldReduceMotion))
        }
    }

    private var legalCard: some View {
        SettingsSection(title: "Legal", accent: accent) {
            VStack(spacing: 0) {
                settingsLinkButton(
                    title: "Privacy Policy",
                    subtitle: "Data and privacy details.",
                    systemImage: "hand.raised.fill",
                    url: Self.privacyPolicyURL
                )

                SettingsDivider()

                settingsLinkButton(
                    title: "Support",
                    subtitle: "Help and contact details.",
                    systemImage: "questionmark.circle.fill",
                    url: Self.supportURL
                )
            }
        }
    }

    private func settingsToggle(
        title: String,
        subtitle: String,
        keyPath: WritableKeyPath<AppSettings, Bool>
    ) -> some View {
        Toggle(
            isOn: Binding(
                get: { store.settings[keyPath: keyPath] },
                set: { newValue in
                    store.updateSettings { settings in
                        settings[keyPath: keyPath] = newValue
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DJTheme.labelFont(15))
                    .foregroundStyle(DJTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(accent)
        .padding(.vertical, 8)
    }

    private func settingsLinkButton(
        title: String,
        subtitle: String,
        systemImage: String,
        url: URL
    ) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 26)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DJTheme.labelFont(15))
                        .foregroundStyle(DJTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(DJTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DJTheme.textSecondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens in browser")
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let accent: Color
    let content: Content

    init(
        title: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(DJTheme.labelFont(12))
                .foregroundStyle(accent)
                .lineLimit(1)

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                .fill(DJTheme.panel.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                .stroke(DJTheme.line, lineWidth: 1)
        )
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(DJTheme.line)
            .frame(height: 1)
    }
}

private struct AccentStyleButton: View {
    let style: DuperAccentStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(style.primaryColor)
                    Circle()
                        .fill(style.secondaryColor)
                }
                .frame(width: 34, height: 16)
                .accessibilityHidden(true)

                Text(style.title)
                    .font(DJTheme.labelFont(14))
                    .foregroundStyle(DJTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? style.primaryColor : DJTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? style.primaryColor.opacity(0.14) : DJTheme.deepDeck.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? style.primaryColor.opacity(0.72) : DJTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(style.title) accent style")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SettingsView()
        .environment(DuperGameStore.preview)
}
