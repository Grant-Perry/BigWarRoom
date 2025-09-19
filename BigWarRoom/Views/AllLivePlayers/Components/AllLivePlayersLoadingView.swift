//
//  AllLivePlayersLoadingView.swift
//  BigWarRoom
//
//  Loading state view for All Live Players
//

import SwiftUI

/// Loading state with spinning football animation and enhanced glowy effects
struct AllLivePlayersLoadingView: View {
    @State private var pulseAnimation = false
    @State private var gradientAnimation = false
    @State private var glowAnimation = false
    
    var body: some View {
        ZStack {
            // 🔥 NEW: Dramatic gradient background like No Leagues Connected
            buildDramaticBackground()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 🔥 ENHANCED: Glowy spinning football with pulsing rings
                buildEnhancedLoadingIndicator()
                
                VStack(spacing: 12) {
                    Text("Loading Players")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Text("Fetching live player data from your leagues...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Enhanced Components
    
    @ViewBuilder
    private func buildDramaticBackground() -> some View {
        // Multi-layer gradient background
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(.systemGray6).opacity(0.1),
                    Color.black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay gradient
            RadialGradient(
                colors: [
                    Color.gpGreen.opacity(gradientAnimation ? 0.3 : 0.1),
                    Color.blue.opacity(gradientAnimation ? 0.2 : 0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: gradientAnimation ? 50 : 200,
                endRadius: gradientAnimation ? 400 : 100
            )
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: gradientAnimation)
            
            // Subtle noise texture
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)
        }
    }
    
    @ViewBuilder
    private func buildEnhancedLoadingIndicator() -> some View {
        ZStack {
            // 🔥 NEW: Pulsing glow rings around the football
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.gpGreen.opacity(glowAnimation ? 0.6 : 0.2),
                                Color.blue.opacity(glowAnimation ? 0.4 : 0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(80 + index * 25))
                    .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                    .opacity(0.7 - Double(index) * 0.15)
                    .animation(
                        .easeInOut(duration: 1.8 + Double(index) * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: pulseAnimation
                    )
            }
            
            // 🔥 NEW: Large pulsing background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gpGreen.opacity(pulseAnimation ? 0.4 : 0.1),
                            Color.blue.opacity(pulseAnimation ? 0.2 : 0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: pulseAnimation ? 120 : 100)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // Original spinning football - now with enhanced scaling
            FantasyLoadingIndicator()
                .scaleEffect(pulseAnimation ? 1.3 : 1.1)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        pulseAnimation = true
        gradientAnimation = true
        glowAnimation = true
    }
}

#Preview {
    AllLivePlayersLoadingView()
}