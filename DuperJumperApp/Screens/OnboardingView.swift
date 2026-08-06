import SwiftUI

struct OnboardingView: View {
    @Environment(DuperGameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var selectedPage = 0

    let onComplete: () -> Void

    private let pages = OnboardingPage.pages

    private var accent: Color {
        store.settings.accentStyle.primaryColor
    }

    private var secondaryAccent: Color {
        store.settings.accentStyle.secondaryColor
    }

    private var shouldReduceMotion: Bool {
        store.settings.reducesMotion(systemReduceMotion: systemReduceMotion)
    }

    private var isLastPage: Bool {
        selectedPage == pages.indices.last
    }

    var body: some View {
        ZStack {
            DuperBackground()

            VStack(spacing: 0) {
                header

                TabView(selection: $selectedPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            accent: index == selectedPage ? pageAccent(for: index) : accent,
                            secondaryAccent: secondaryAccent,
                            reduceMotion: shouldReduceMotion
                        )
                        .tag(index)
                        .padding(.horizontal, DJTheme.pagePadding)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 16) {
                    pageIndicator

                    Button {
                        advance()
                    } label: {
                        Label(isLastPage ? "Start Playing" : "Next", systemImage: isLastPage ? "play.fill" : "arrow.right")
                    }
                    .buttonStyle(DuperButtonStyle(accent: accent, reduceMotion: shouldReduceMotion))
                    .padding(.horizontal, DJTheme.pagePadding)
                    .accessibilityHint(isLastPage ? "Finishes onboarding" : "Moves to the next onboarding page")
                }
                .padding(.bottom, 22)
            }
        }
        .preferredColorScheme(.dark)
        .animation(shouldReduceMotion ? nil : .snappy(duration: 0.22), value: selectedPage)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DUPER JUMPER")
                    .font(DJTheme.titleFont(20))
                    .foregroundStyle(DJTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text("Fast climbs. Clean stops.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 12)

            Button("Skip", action: onComplete)
                .font(DJTheme.labelFont(13))
                .foregroundStyle(DJTheme.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(DJTheme.panel.opacity(0.72), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(DJTheme.line, lineWidth: 1)
                )
                .accessibilityHint("Skips onboarding")
        }
        .padding(.horizontal, DJTheme.pagePadding)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? pageAccent(for: index) : DJTheme.line)
                    .frame(width: index == selectedPage ? 26 : 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Onboarding page \(selectedPage + 1) of \(pages.count)")
    }

    private func advance() {
        guard !isLastPage else {
            onComplete()
            return
        }

        selectedPage += 1
    }

    private func pageAccent(for index: Int) -> Color {
        pages[index].accent
    }
}

private struct OnboardingPage: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let message: String
    let symbolName: String
    let accent: Color
    let callouts: [OnboardingCallout]

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: "climb",
            eyebrow: "Core Loop",
            title: "Climb one clean step at a time.",
            message: "Start a round, read the tower, and keep moving upward while your timing still feels sharp.",
            symbolName: "figure.stairs",
            accent: DJTheme.electricCyan,
            callouts: [
                OnboardingCallout(title: "Tap Jump", value: "Build height", symbolName: "arrow.up"),
                OnboardingCallout(title: "Watch Risk", value: "Stay readable", symbolName: "exclamationmark.triangle.fill")
            ]
        ),
        OnboardingPage(
            id: "risk",
            eyebrow: "Momentum",
            title: "Every higher step raises the pressure.",
            message: "Good runs are not only about going farther. They are about knowing when the next jump is still worth it.",
            symbolName: "bolt.fill",
            accent: DJTheme.pulseMagenta,
            callouts: [
                OnboardingCallout(title: "Multiplier", value: "Grows faster", symbolName: "xmark"),
                OnboardingCallout(title: "Bonuses", value: "Shift the odds", symbolName: "sparkles")
            ]
        ),
        OnboardingPage(
            id: "collect",
            eyebrow: "Personal Bests",
            title: "Bank the run before it slips.",
            message: "Collect points when the climb is strong, unlock local milestones, and come back for a cleaner best.",
            symbolName: "checkmark.seal.fill",
            accent: DJTheme.signalMint,
            callouts: [
                OnboardingCallout(title: "Collect", value: "Save points", symbolName: "tray.and.arrow.down.fill"),
                OnboardingCallout(title: "Achievements", value: "Track progress", symbolName: "sparkles")
            ]
        )
    ]
}

private struct OnboardingCallout: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let symbolName: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let accent: Color
    let secondaryAccent: Color
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let compactHeight = proxy.size.height < 560

            VStack(spacing: compactHeight ? 14 : 20) {
                Spacer(minLength: compactHeight ? 2 : 12)

                OnboardingHero(
                    symbolName: page.symbolName,
                    accent: accent,
                    secondaryAccent: secondaryAccent,
                    reduceMotion: reduceMotion,
                    compactHeight: compactHeight
                )

                VStack(spacing: compactHeight ? 10 : 14) {
                    Text(page.eyebrow.uppercased())
                        .font(DJTheme.labelFont(12))
                        .foregroundStyle(accent)
                        .lineLimit(1)

                    Text(page.title)
                        .font(DJTheme.titleFont(compactHeight ? 27 : 32))
                        .foregroundStyle(DJTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.message)
                        .font(.system(size: compactHeight ? 14 : 16, weight: .medium, design: .rounded))
                        .foregroundStyle(DJTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 10) {
                    ForEach(page.callouts) { callout in
                        OnboardingCalloutCard(callout: callout, accent: accent)
                    }
                }

                Spacer(minLength: compactHeight ? 2 : 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct OnboardingHero: View {
    let symbolName: String
    let accent: Color
    let secondaryAccent: Color
    let reduceMotion: Bool
    let compactHeight: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DJTheme.panelBright.opacity(0.86),
                            DJTheme.deepDeck.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [accent.opacity(0.82), secondaryAccent.opacity(0.42)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            Image("logo-jumper")
                .resizable()
                .scaledToFill()
                .frame(width: compactHeight ? 148 : 184, height: compactHeight ? 148 : 184)
                .clipShape(RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                        .stroke(accent.opacity(0.44), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.38), radius: 18, x: 0, y: 12)
                .offset(y: reduceMotion ? 0 : -6)

            Image(systemName: symbolName)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(DJTheme.void)
                .frame(width: 50, height: 50)
                .background(accent, in: RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                        .stroke(DJTheme.textPrimary.opacity(0.42), lineWidth: 1)
                )
                .offset(x: 92, y: compactHeight ? 66 : 82)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: 310)
        .frame(height: compactHeight ? 190 : 232)
        .shadow(color: accent.opacity(0.16), radius: 24, x: 0, y: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Duper Jumper logo")
    }
}

private struct OnboardingCalloutCard: View {
    let callout: OnboardingCallout
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: callout.symbolName)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(callout.title.uppercased())
                    .font(DJTheme.labelFont(10))
                    .foregroundStyle(DJTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text(callout.value)
                    .font(DJTheme.labelFont(14))
                    .foregroundStyle(DJTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DJTheme.panel.opacity(0.74), in: RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                .stroke(accent.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView { }
        .environment(DuperGameStore.preview)
}
