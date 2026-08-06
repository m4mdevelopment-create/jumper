//
//  ContentView.swift
//  DuperJumperApp
//
//  Created by Никита on 17.06.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var gameStore = DuperGameStore()
    @AppStorage("hasCompletedDuperOnboarding.v1") private var hasCompletedOnboarding = false

    var body: some View {
        nativeContent
            .environment(gameStore)
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var nativeContent: some View {
        if hasCompletedOnboarding {
            AppShellView()
        } else {
            OnboardingView {
                withAnimation(.snappy(duration: 0.28)) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
