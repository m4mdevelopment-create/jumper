//
//  ContentView.swift
//  DuperJumperApp
//
//  Created by Никита on 17.06.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var gameStore = DuperGameStore()
    @State private var isShowingLaunchSplash = true
    @AppStorage("hasCompletedDuperOnboarding.v1") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            Group {
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

            if isShowingLaunchSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environment(gameStore)
        .task {
            await hideLaunchSplashAfterDelay()
        }
    }

    @MainActor
    private func hideLaunchSplashAfterDelay() async {
        do {
            try await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            isShowingLaunchSplash = false
        }
    }
}

private struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isIconVisible = true

    var body: some View {
        ZStack {
            DuperBackground()

            Image("logo-jumper")
                .resizable()
                .scaledToFill()
                .frame(width: 148, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(DJTheme.electricCyan.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: DJTheme.electricCyan.opacity(0.32), radius: 26, x: 0, y: 12)
                .opacity(reduceMotion ? 1 : (isIconVisible ? 1 : 0.38))
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 0.48).repeatForever(autoreverses: true)) {
                isIconVisible = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Duper Jumper launch screen")
    }
}

#Preview {
    ContentView()
}
