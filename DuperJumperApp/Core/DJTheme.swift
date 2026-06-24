import SwiftUI

enum DJTheme {
    static let void = Color(red: 0.025, green: 0.030, blue: 0.055)
    static let deepDeck = Color(red: 0.055, green: 0.065, blue: 0.115)
    static let panel = Color(red: 0.090, green: 0.105, blue: 0.170)
    static let panelBright = Color(red: 0.130, green: 0.150, blue: 0.235)
    static let line = Color.white.opacity(0.12)
    static let textPrimary = Color(red: 0.950, green: 0.980, blue: 1.000)
    static let textSecondary = Color(red: 0.670, green: 0.735, blue: 0.820)
    static let electricCyan = Color(red: 0.175, green: 0.910, blue: 1.000)
    static let pulseMagenta = Color(red: 1.000, green: 0.270, blue: 0.780)
    static let voltAmber = Color(red: 1.000, green: 0.760, blue: 0.250)
    static let signalMint = Color(red: 0.300, green: 0.960, blue: 0.660)
    static let riskRed = Color(red: 1.000, green: 0.380, blue: 0.420)
    static let stableBlue = Color(red: 0.360, green: 0.520, blue: 1.000)

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 8

    static func titleFont(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func labelFont(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func monoFont(_ size: CGFloat = 18, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct DuperBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DJTheme.void, DJTheme.deepDeck, Color(red: 0.035, green: 0.040, blue: 0.075)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    ForEach(0..<7, id: \.self) { index in
                        Rectangle()
                            .fill(DJTheme.electricCyan.opacity(index == 3 ? 0.20 : 0.07))
                            .frame(width: index == 3 ? 2 : 1)
                            .position(
                                x: width * CGFloat(index + 1) / 8,
                                y: height / 2
                            )
                    }

                    ForEach(0..<10, id: \.self) { index in
                        Rectangle()
                            .fill(DJTheme.line.opacity(0.55))
                            .frame(height: 1)
                            .position(
                                x: width / 2,
                                y: height * CGFloat(index + 1) / 11
                            )
                    }

                    Circle()
                        .stroke(DJTheme.pulseMagenta.opacity(0.18), lineWidth: 2)
                        .frame(width: min(width, height) * 0.72)
                        .position(x: width * 0.12, y: height * 0.18)

                    Circle()
                        .stroke(DJTheme.voltAmber.opacity(0.16), lineWidth: 1)
                        .frame(width: min(width, height) * 0.56)
                        .position(x: width * 0.88, y: height * 0.74)
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct DuperScreen<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: Color
    let content: Content

    init(
        title: String,
        subtitle: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        ZStack {
            DuperBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.uppercased())
                            .font(DJTheme.titleFont())
                            .foregroundStyle(DJTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        Text(subtitle)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(DJTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 14)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: 58, height: 4)
                            .offset(y: -12)
                    }

                    content
                }
                .padding(.horizontal, DJTheme.pagePadding)
                .padding(.bottom, 28)
            }
        }
        .toolbarBackground(DJTheme.deepDeck, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct NeonCardModifier: ViewModifier {
    let accent: Color
    var isBright: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                    .fill(isBright ? DJTheme.panelBright.opacity(0.92) : DJTheme.panel.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.72), DJTheme.line],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: accent.opacity(0.16), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func neonCard(accent: Color = DJTheme.electricCyan, isBright: Bool = false) -> some View {
        modifier(NeonCardModifier(accent: accent, isBright: isBright))
    }
}

struct DuperButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
        case danger
    }

    let accent: Color
    var role: Role = .primary
    var reduceMotion = false

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.isEnabled) private var isEnabled

    init(accent: Color, role: Role = .primary, reduceMotion: Bool = false) {
        self.accent = accent
        self.role = role
        self.reduceMotion = reduceMotion
    }

    func makeBody(configuration: Configuration) -> some View {
        let shouldReduceMotion = reduceMotion || systemReduceMotion

        configuration.label
            .font(DJTheme.labelFont(15))
            .foregroundStyle(isEnabled ? foregroundColor : DJTheme.textSecondary.opacity(0.78))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(background(configuration: configuration))
            .overlay(
                RoundedRectangle(cornerRadius: DJTheme.cardRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.58)
            .scaleEffect(isEnabled && !shouldReduceMotion && configuration.isPressed ? 0.98 : 1.0)
            .animation(isEnabled && !shouldReduceMotion ? .snappy(duration: 0.16) : nil, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        role == .primary ? DJTheme.void : DJTheme.textPrimary
    }

    private var borderColor: Color {
        guard isEnabled else { return DJTheme.line }
        return role == .danger ? DJTheme.riskRed.opacity(0.72) : accent.opacity(0.72)
    }

    private func background(configuration: Configuration) -> AnyShapeStyle {
        guard isEnabled else {
            return AnyShapeStyle(DJTheme.deepDeck.opacity(0.62))
        }

        let opacity = configuration.isPressed ? 0.74 : 1.0

        switch role {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [accent.opacity(opacity), DJTheme.signalMint.opacity(0.82 * opacity)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(DJTheme.panelBright.opacity(configuration.isPressed ? 0.65 : 0.90))
        case .danger:
            return AnyShapeStyle(DJTheme.riskRed.opacity(configuration.isPressed ? 0.22 : 0.14))
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(DJTheme.labelFont(11))
                .foregroundStyle(DJTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(value)
                .font(DJTheme.monoFont(22, weight: .black))
                .foregroundStyle(DJTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonCard(accent: accent)
    }
}
