//
//  ContentView.swift
//  DuperJumperApp
//
//  Created by Никита on 17.06.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var gameStore = DuperGameStore()
    @State private var launchCoordinator = AppLaunchCoordinator()
    @AppStorage("hasCompletedDuperOnboarding.v1") private var hasCompletedOnboarding = false

    var body: some View {
        routedContent
        .environment(gameStore)
        .preferredColorScheme(.dark)
        .task {
            await AppDelegate.requestTrackingAuthorizationAndStartAppsFlyer()
            await launchCoordinator.start()
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        switch launchCoordinator.route {
        case .loading:
            LaunchLoadingView()
        case .noInternet(let message):
            NoInternetView(message: message) {
                launchCoordinator.retry()
            }
        case .fanContent:
            fanContent
        case .notificationPrompt:
            NotificationPermissionPrimerView(
                acceptAction: {
                    launchCoordinator.acceptNotifications()
                },
                skipAction: {
                    launchCoordinator.skipNotifications()
                }
            )
        case .webView(let url):
            DuperWebView(url: url)
        }
    }

    @ViewBuilder
    private var fanContent: some View {
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

private struct LaunchLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isIconVisible = true

    var body: some View {
        ZStack {
            DuperBackground()

            VStack(spacing: 18) {
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

                ProgressView()
                    .tint(DJTheme.electricCyan)
                    .controlSize(.large)
            }
            .padding(.horizontal, 28)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 0.48).repeatForever(autoreverses: true)) {
                isIconVisible = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

private struct NoInternetView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        ZStack {
            DuperBackground()

            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(DJTheme.voltAmber)
                    .accessibilityHidden(true)

                VStack(spacing: 7) {
                    Text("No Internet")
                        .font(DJTheme.titleFont(26))
                        .foregroundStyle(DJTheme.textPrimary)

                    Text(message)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(DJTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: retryAction) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(DuperButtonStyle(accent: DJTheme.voltAmber))
            }
            .frame(maxWidth: 360)
            .padding(20)
            .neonCard(accent: DJTheme.voltAmber)
            .padding(.horizontal, 22)
        }
    }
}

private struct NotificationPermissionPrimerView: View {
    let acceptAction: () -> Void
    let skipAction: () -> Void

    var body: some View {
        ZStack {
            DuperBackground()

            VStack(spacing: 16) {
                Image("logo-jumper")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(DJTheme.signalMint.opacity(0.72), lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Stay Updated")
                        .font(DJTheme.titleFont(26))
                        .foregroundStyle(DJTheme.textPrimary)

                    Text("Receive timely updates and bonus alerts.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(DJTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button(action: acceptAction) {
                        Label("Yes, I Want Bonuses!", systemImage: "bell.badge.fill")
                    }
                    .buttonStyle(DuperButtonStyle(accent: DJTheme.signalMint))

                    Button(action: skipAction) {
                        Text("Skip")
                    }
                    .buttonStyle(DuperButtonStyle(accent: DJTheme.signalMint, role: .secondary))
                }
            }
            .frame(maxWidth: 380)
            .padding(20)
            .neonCard(accent: DJTheme.signalMint)
            .padding(.horizontal, 22)
        }
    }
}

#Preview {
    ContentView()
}
