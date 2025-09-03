//
//  LoadingScreen.swift
//  BigWarRoom
//
//  Beautiful loading screen with purple/blue gradients, bokeh effects, and growing app logo
//

import SwiftUI

struct LoadingScreen: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoGlow: CGFloat = 0.3
    @State private var purpleExpansion: CGFloat = 0
    @State private var showPurpleExpansion = false
    @State private var gradientRotation: Double = 0
    @State private var isComplete = false
    
    /// Completion handler - true if needs onboarding, false if ready to go
    let onComplete: (Bool) -> Void
    
    /// Credentials managers for checking setup status
    @StateObject private var espnCredentials = ESPNCredentialsManager.shared
    @StateObject private var sleeperCredentials = SleeperCredentialsManager.shared
    
    var body: some View {
        ZStack {
            // Base animated gradient background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.9),
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.7),
                    Color.blue.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .rotationEffect(.degrees(gradientRotation))
            .ignoresSafeArea()
            
            // Purple expansion overlay - subtle expansion effect
            if showPurpleExpansion {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.purple.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 400 * purpleExpansion
                        )
                    )
                    .scaleEffect(purpleExpansion)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 1.0), value: purpleExpansion)
            }
            
            // Bokeh background effects
            BokehLayer()
                .opacity(showPurpleExpansion ? 0.6 : 1.0)
            
            // Main content
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo with beautiful growing effect - NO PROGRESS BAR!
                AppConstants.appLogo
                    .scaleEffect(logoScale)
                    .shadow(color: .purple.opacity(logoGlow), radius: 20, x: 0, y: 0)
                    .shadow(color: .blue.opacity(logoGlow * 0.8), radius: 30, x: 0, y: 0)
                    .animation(.easeInOut(duration: 2.0), value: logoScale)
                    .animation(.easeInOut(duration: 1.5), value: logoGlow)
                
                Spacer()
                
                // Subtle app name
                Text("BigWarRoom")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(logoScale > 0.8 ? 1.0 : 0.0)
                    .animation(.easeIn(duration: 1.0).delay(1.0), value: logoScale)
                
                Spacer()
            }
        }
        .onAppear {
            startLoadingSequence()
        }
    }
    
    /// Starts the beautiful loading animation sequence with growing logo
    private func startLoadingSequence() {
        // Grow the logo from small to normal size
        withAnimation(.easeOut(duration: 1.5)) {
            logoScale = 1.0
        }
        
        // Intensify glow effect 
        withAnimation(.easeInOut(duration: 1.8).delay(0.2)) {
            logoGlow = 1.0
        }
        
        // Trigger subtle purple expansion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            triggerPurpleExpansion()
        }
        
        // Background gradient rotation
        withAnimation(.linear(duration: 2.0)) {
            gradientRotation = 10
        }
        
        // Complete after 2 seconds total
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completeLoading()
        }
    }
    
    /// Triggers the subtle purple expansion effect
    private func triggerPurpleExpansion() {
        showPurpleExpansion = true
        
        withAnimation(.easeOut(duration: 0.8)) {
            purpleExpansion = 1.5
        }
    }
    
    /// Always loads SettingsView (OnBoardingView) - no credential checking
    private func completeLoading() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isComplete = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Always show onboarding/settings - let user choose what to do
            onComplete(true)
        }
    }
}

// MARK: - Bokeh Background Layer

struct BokehLayer: View {
    @State private var positions: [(CGPoint, CGFloat, Color, Double)] = []
    
    var body: some View {
        ZStack {
            ForEach(0..<15, id: \.self) { index in
                if positions.indices.contains(index) {
                    let (position, size, color, opacity) = positions[index]
                    
                    Circle()
                        .fill(color.opacity(opacity))
                        .frame(width: size, height: size)
                        .position(position)
                        .blur(radius: size * 0.3)
                }
            }
        }
        .onAppear {
            generateBokehPositions()
            startBokehAnimation()
        }
    }
    
    private func generateBokehPositions() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        positions = (0..<15).map { _ in
            let x = CGFloat.random(in: 0...screenWidth)
            let y = CGFloat.random(in: 0...screenHeight)
            let size = CGFloat.random(in: 30...120)
            let color = [Color.purple, Color.blue, Color.white].randomElement()!
            let opacity = Double.random(in: 0.1...0.4)
            
            return (CGPoint(x: x, y: y), size, color, opacity)
        }
    }
    
    private func startBokehAnimation() {
        withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
            positions = positions.map { (position, size, color, opacity) in
                let newX = position.x + CGFloat.random(in: -50...50)
                let newY = position.y + CGFloat.random(in: -50...50)
                return (CGPoint(x: newX, y: newY), size, color, opacity)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LoadingScreen { _ in
        print("Loading complete! Always showing settings.")
    }
}