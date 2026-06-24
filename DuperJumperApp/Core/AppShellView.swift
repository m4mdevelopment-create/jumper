import SwiftUI

struct AppShellView: View {
    @Environment(DuperGameStore.self) private var store

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
            ForEach(DuperTab.allCases) { tab in
                NavigationStack {
                    tab.makeContentView()
                        .navigationTitle(tab.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.symbolName)
                }
                .tag(tab)
            }
        }
        .tint(store.settings.accentStyle.primaryColor)
        .toolbarBackground(DJTheme.deepDeck, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}

private extension DuperTab {
    @ViewBuilder
    func makeContentView() -> some View {
        switch self {
        case .game:
            GameView()
        case .achievements:
            AchievementsView()
        case .guide:
            GuideView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    AppShellView()
        .environment(DuperGameStore.preview)
}
