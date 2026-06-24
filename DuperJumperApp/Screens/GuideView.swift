import SwiftUI

struct GuideView: View {
    @Environment(DuperGameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private let articles = GuideArticleContent.all

    private var shouldReduceMotion: Bool {
        store.settings.reducesMotion(systemReduceMotion: systemReduceMotion)
    }

    var body: some View {
        DuperScreen(
            title: "Guide",
            subtitle: "Short reads about vertical progress, timing, focus, and personal bests.",
            accent: DJTheme.voltAmber
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if let featuredArticle = articles.first {
                    FeaturedGuideArticleCard(
                        article: featuredArticle,
                        isRead: isRead(featuredArticle)
                    )
                }

                readingQueueHeader

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 156), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(articles.dropFirst()) { article in
                        GuideArticleCard(
                            article: article,
                            isRead: isRead(article)
                        )
                    }
                }
            }
        }
        .navigationDestination(for: String.self) { articleID in
            if let article = articles.first(where: { $0.id == articleID }) {
                GuideArticleDetailView(
                    article: article,
                    isRead: isRead(article),
                    reduceMotion: shouldReduceMotion,
                    markRead: { markArticleRead(article) }
                )
            }
        }
    }

    private var readingQueueHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reading Queue")
                    .font(DJTheme.labelFont(17))
                    .foregroundStyle(DJTheme.textPrimary)

                Text("\(articles.count) concise reads for timing, focus, risk, and progress")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
            }

            Spacer()

            Text("\(readCount)/\(articles.count)")
                .font(DJTheme.monoFont(16, weight: .black))
                .foregroundStyle(DJTheme.voltAmber)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DJTheme.voltAmber.opacity(0.14), in: Capsule())
                .accessibilityLabel("\(readCount) of \(articles.count) articles read")
        }
    }

    private var readCount: Int {
        articles.filter { isRead($0) }.count
    }

    private func isRead(_ article: GuideArticleContent) -> Bool {
        store.guideArticles.first(where: { $0.id == article.id })?.isRead ?? false
    }

    private func markArticleRead(_ article: GuideArticleContent) {
        guard let storedArticle = store.guideArticles.first(where: { $0.id == article.id }) else { return }
        store.markArticleRead(storedArticle)
    }
}

private struct GuideArticleContent: Identifiable {
    let id: String
    let title: String
    let category: String
    let summary: String
    let readTimeMinutes: Int
    let iconName: String
    let accent: Color
    let sections: [String]

    static let all: [GuideArticleContent] = [
        GuideArticleContent(
            id: "core-loop",
            title: "Reading the Climb",
            category: "Climb Sense",
            summary: "Notice pace, height, and confidence before choosing the next upward step.",
            readTimeMinutes: 2,
            iconName: "arrow.up.right.circle.fill",
            accent: DJTheme.voltAmber,
            sections: [
                "Vertical progress is easiest to read when it has a rhythm. Watch how fast the climb is building, where attention starts to tighten, and whether the next move still feels deliberate.",
                "A pause is not a break in momentum; it is a way to keep momentum useful. When the climb feels readable, the next step carries more information than a rushed reaction.",
                "Treat height as feedback rather than proof. A clean stretch shows which cues are dependable, while a shaky stretch points to the spot where timing needs to settle."
            ]
        ),
        GuideArticleContent(
            id: "multiplier-meter",
            title: "When to Collect",
            category: "Timing",
            summary: "Set a stop point while focus is clear, then respect it before rhythm gets noisy.",
            readTimeMinutes: 2,
            iconName: "checkmark.seal.fill",
            accent: DJTheme.signalMint,
            sections: [
                "Good timing often starts before the pressure arrives. Decide what a clean stopping point looks like while the pattern is still calm.",
                "The reward for waiting should be weighed against the cost of losing clarity. If the next choice feels automatic, the useful signal may already be fading.",
                "A steady reset protects the next attempt. Keeping the finish intentional makes progress easier to compare from one climb to the next."
            ]
        ),
        GuideArticleContent(
            id: "safe-design",
            title: "Momentum and Focus",
            category: "Focus",
            summary: "Use short mental resets to keep quick decisions crisp instead of hurried.",
            readTimeMinutes: 3,
            iconName: "scope",
            accent: DJTheme.electricCyan,
            sections: [
                "Focus works best when it has one job. Choose a cue such as spacing, timing, or the next clean beat, then let everything else stay in the background.",
                "Momentum can sharpen attention, but it can also crowd it. When the pace rises, a small reset keeps decisions from becoming a blur.",
                "A missed beat is most useful when it stays contained. Let the next attempt begin with a clear cue instead of carrying the last mistake forward."
            ]
        ),
        GuideArticleContent(
            id: "tiny-risks",
            title: "Tiny Risks, Better Runs",
            category: "Decision",
            summary: "Take small, deliberate risks so each attempt teaches something useful.",
            readTimeMinutes: 2,
            iconName: "bolt.fill",
            accent: DJTheme.pulseMagenta,
            sections: [
                "Risk is easiest to manage when it stays narrow. One extra beat, one higher target, or one later stop gives clear feedback without turning the whole attempt into a guess.",
                "The reward is not only a better result; it is a better read of what actually changed. Small adjustments make cause and effect visible.",
                "When a choice pays off, repeat it once before raising the stakes. Consistency turns a lucky moment into a pattern you can trust."
            ]
        ),
        GuideArticleContent(
            id: "personal-best",
            title: "Building a Personal Best",
            category: "Progress",
            summary: "Use repeated attempts as feedback, not pressure, and track what changed.",
            readTimeMinutes: 1,
            iconName: "chart.line.uptrend.xyaxis",
            accent: DJTheme.stableBlue,
            sections: [
                "A personal best matters most when its cause is visible. Look for the detail that improved: calmer timing, cleaner focus, or a better sense of when to stop.",
                "Not every attempt needs to be a record. Some attempts are useful because they make the next record easier to understand.",
                "Progress becomes durable when the target stays simple. Improve one cue, repeat it, and let the best result follow the cleaner process."
            ]
        )
    ]
}

private struct FeaturedGuideArticleCard: View {
    let article: GuideArticleContent
    let isRead: Bool

    var body: some View {
        NavigationLink(value: article.id) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    GuideIcon(
                        systemName: article.iconName,
                        accent: article.accent,
                        size: 40
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Featured")
                            .font(DJTheme.labelFont(12))
                            .foregroundStyle(article.accent)

                        Text(article.category.uppercased())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(DJTheme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    ReadStatusBadge(isRead: isRead, accent: article.accent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(DJTheme.titleFont(21))
                        .foregroundStyle(DJTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.summary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(DJTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    GuideInfoPill(text: "\(article.readTimeMinutes) min read", systemName: "clock")
                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(article.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .neonCard(accent: article.accent)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the featured guide article")
    }
}

private struct GuideArticleCard: View {
    let article: GuideArticleContent
    let isRead: Bool

    var body: some View {
        NavigationLink(value: article.id) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    GuideIcon(
                        systemName: article.iconName,
                        accent: article.accent,
                        size: 34
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(article.category.uppercased())
                            .font(DJTheme.labelFont(11))
                            .foregroundStyle(article.accent)

                        Text(article.title)
                            .font(DJTheme.labelFont(16))
                            .foregroundStyle(DJTheme.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isRead ? DJTheme.signalMint : DJTheme.textSecondary)
                }

                Text(article.summary)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(DJTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Label("\(article.readTimeMinutes) min", systemImage: "clock")
                        .font(DJTheme.labelFont(12))
                        .foregroundStyle(DJTheme.textSecondary)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(article.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .neonCard(accent: article.accent)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens article details")
    }
}

private struct GuideArticleDetailView: View {
    let article: GuideArticleContent
    let isRead: Bool
    let reduceMotion: Bool
    let markRead: () -> Void

    var body: some View {
        ZStack {
            DuperBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(article.sections.enumerated()), id: \.offset) { index, section in
                            GuideParagraphRow(
                                index: index + 1,
                                text: section,
                                accent: article.accent
                            )
                        }
                    }
                    .neonCard(accent: article.accent)

                    HStack {
                        Spacer()

                        GuideMarkReadButton(
                            isRead: isRead,
                            accent: article.accent,
                            reduceMotion: reduceMotion,
                            action: markRead
                        )
                    }
                }
                .padding(.horizontal, DJTheme.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DJTheme.deepDeck, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                GuideIcon(
                    systemName: article.iconName,
                    accent: article.accent,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(article.category.uppercased())
                        .font(DJTheme.labelFont(12))
                        .foregroundStyle(article.accent)

                    Text("\(article.readTimeMinutes) min read")
                        .font(DJTheme.labelFont(12))
                        .foregroundStyle(DJTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            Text(article.title)
                .font(DJTheme.titleFont(24))
                .foregroundStyle(DJTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(article.summary)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(DJTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .neonCard(accent: article.accent)
    }
}

private struct GuideParagraphRow: View {
    let index: Int
    let text: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(DJTheme.monoFont(12, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(DJTheme.textPrimary.opacity(0.9))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GuideMarkReadButton: View {
    let isRead: Bool
    let accent: Color
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(isRead ? "Read" : "Mark Read", systemImage: isRead ? "checkmark.circle.fill" : "checkmark.circle")
                .font(DJTheme.labelFont(13))
                .foregroundStyle(isRead ? DJTheme.signalMint : DJTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(buttonAccent.opacity(0.12), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(buttonAccent.opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isRead)
        .opacity(isRead ? 0.72 : 1.0)
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: isRead)
    }

    private var buttonAccent: Color {
        isRead ? DJTheme.signalMint : accent
    }
}

private struct GuideIcon: View {
    let systemName: String
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.16))
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(accent)
        }
    }
}

private struct GuideInfoPill: View {
    let text: String
    let systemName: String

    var body: some View {
        Label(text, systemImage: systemName)
            .font(DJTheme.labelFont(12))
            .foregroundStyle(DJTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(DJTheme.deepDeck.opacity(0.72), in: Capsule())
    }
}

private struct ReadStatusBadge: View {
    let isRead: Bool
    let accent: Color

    var body: some View {
        Text(isRead ? "Read" : "New")
            .font(DJTheme.labelFont(12))
            .foregroundStyle(isRead ? DJTheme.signalMint : accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isRead ? DJTheme.signalMint : accent).opacity(0.14), in: Capsule())
    }
}

#Preview {
    GuideView()
        .environment(DuperGameStore.preview)
}
