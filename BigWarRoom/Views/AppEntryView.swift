//
//  AppEntryView.swift
//  BigWarRoom
//
//  Entry point that handles loading screen and onboarding flow
//

import SwiftUI

struct AppEntryView: View {
    @State private var showingLoading = true
    @State private var needsOnboarding = false
    
    var body: some View {
        Group {
            if showingLoading {
                LoadingScreen { needsOnboardingResult in
                    needsOnboarding = needsOnboardingResult
                    showingLoading = false
                }
            } else if needsOnboarding {
                OnBoardingView()
            } else {
                BigWarRoom()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showingLoading)
    }
}

// MARK: - Preview

#Preview("Loading") {
    AppEntryView()
}

#Preview("Onboarding Needed") {
    struct PreviewWrapper: View {
        var body: some View {
            AppEntryView()
                .onAppear {
                    // Clear credentials for preview
                    ESPNCredentialsManager.shared.clearCredentials()
                    SleeperCredentialsManager.shared.clearCredentials()
                }
        }
    }
    
    return PreviewWrapper()
}