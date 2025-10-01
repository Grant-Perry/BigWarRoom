//
//  AllLivePlayersLoadingView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Migrated to use UnifiedLoadingView while preserving animations
//  All original animations and visual effects are maintained through the unified system
//

import SwiftUI

/// **AllLivePlayers Loading View** - Now using UnifiedLoadingSystem
/// **All animations preserved:** pulseAnimation, gradientAnimation, glowAnimation
struct AllLivePlayersLoadingView: View {
    @State private var pulseAnimation = false
    @State private var gradientAnimation = false
    @State private var glowAnimation = false
    
    var body: some View {
        UnifiedLoadingView(
            configuration: .allLivePlayers(
                pulseAnimation: $pulseAnimation,
                gradientAnimation: $gradientAnimation, 
                glowAnimation: $glowAnimation
            )
        )
        .onAppear {
            startAnimations()
        }
    }
    
    /// **Animation Control** - PRESERVED EXACTLY AS ORIGINAL
    private func startAnimations() {
        pulseAnimation = true
        gradientAnimation = true
        glowAnimation = true
    }
}

#Preview {
    AllLivePlayersLoadingView()
}