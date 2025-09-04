//
//  LoadingScreen.swift
//  BigWarRoom
//
//  Beautiful splash screen with purple/blue gradients, bokeh effects, and growing app logo
//

import SwiftUI

struct LoadingScreen: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoGlow: CGFloat = 0.3
    @State private var textOpacity: Double = 0.0
    @State private var purpleWave: CGFloat = 0
    @State private var isComplete = false
    
    /// Completion handler 
    let onComplete: (Bool) -> Void
    
    /// Credentials managers for checking persistent data
    @StateObject private var espnCredentials = ESPNCredentialsManager.shared
    @StateObject private var sleeperCredentials = SleeperCredentialsManager.shared
    
    var body: some View {
        ZStack {
            // Static beautiful gradient background
            LinearGradient(
                colors: [
				  Color.marlinsPrimary.opacity(0.9),
				  Color.rockiesPrimary.opacity(0.8),
				  Color.marlinsPrimary.opacity(0.7),
				  Color.rockiesPrimary.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle animated wave overlay
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.2),
                            Color.blue.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .scaleEffect(purpleWave)
                .ignoresSafeArea()
            
            // Bokeh background effects
            BokehLayer()
                .opacity(0.6)
            
            // Main content
            VStack(spacing: 50) {
                Spacer()
                
                // App Logo with version underneath
                VStack(spacing: 12) {
                    AppConstants.appLogo
                        .scaleEffect(logoScale)
                        .shadow(color: .purple.opacity(logoGlow), radius: 20, x: 0, y: 0)
                        .shadow(color: .blue.opacity(logoGlow * 0.8), radius: 30, x: 0, y: 0)
                        .animation(.spring(response: 1.5, dampingFraction: 0.8), value: logoScale)
                        .animation(.easeInOut(duration: 2.0), value: logoGlow)
                    
                    // Version under the AppIcon
                    Text("Version \(AppConstants.getVersion())")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(textOpacity)
                }
                
                // App name and tagline
                VStack(spacing: 16) {
                    Text("BigWarRoom")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(textOpacity)
                    
                    Text("Your Fantasy Football Command Center")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                }
                .animation(.easeIn(duration: 1.0).delay(1.0), value: textOpacity)
                
                Spacer()
                
                // Loading dots
                LoadingDots()
                    .opacity(textOpacity)
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            startSplashSequence()
        }
    }
    
    /// Starts the beautiful splash animation sequence
    private func startSplashSequence() {
        // Grow the logo
        withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.3)) {
            logoScale = 1.0
        }
        
        // Intensify glow
        withAnimation(.easeInOut(duration: 1.8).delay(0.5)) {
            logoGlow = 1.0
        }
        
        // Show text
        withAnimation(.easeIn(duration: 0.8).delay(1.2)) {
            textOpacity = 1.0
        }
        
        // Subtle wave animation
        withAnimation(.easeOut(duration: 2.0).delay(0.8)) {
            purpleWave = 1.5
        }
        
        // Complete after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            completeLoading()
        }
    }
    
    /// Checks if user has persistent data and completes loading
    private func completeLoading() {
        // Check if user has any valid credentials setup
        let hasESPNCredentials = espnCredentials.hasValidCredentials
        let hasSleeperCredentials = sleeperCredentials.hasValidCredentials
        
        // If user has EITHER ESPN OR Sleeper credentials, skip onboarding
        let hasAnyCredentials = hasESPNCredentials || hasSleeperCredentials
        
        // xprint("🔍 Loading screen check - ESPN: \(hasESPNCredentials), Sleeper: \(hasSleeperCredentials), Any: \(hasAnyCredentials)")
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isComplete = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only show onboarding if NO credentials exist
            let shouldShowOnboarding = !hasAnyCredentials
            onComplete(shouldShowOnboarding)
        }
    }
}

// MARK: - Loading Dots Animation

struct LoadingDots: View {
    @State private var animationPhase: Int = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            withAnimation {
                animationPhase = 0
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Bokeh Background Layer

struct BokehLayer: View {
    @State private var positions: [(CGPoint, CGFloat, Color, Double)] = []
    
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                if positions.indices.contains(index) {
                    let (position, size, color, opacity) = positions[index]
                    
                    Circle()
                        .fill(color.opacity(opacity))
                        .frame(width: size, height: size)
                        .position(position)
                        .blur(radius: size * 0.4)
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
        
        positions = (0..<12).map { _ in
            let x = CGFloat.random(in: 0...screenWidth)
            let y = CGFloat.random(in: 0...screenHeight)
            let size = CGFloat.random(in: 40...100)
            let color = [Color.purple, Color.blue, Color.white].randomElement()!
            let opacity = Double.random(in: 0.1...0.3)
            
            return (CGPoint(x: x, y: y), size, color, opacity)
        }
    }
    
    private func startBokehAnimation() {
        withAnimation(.easeInOut(duration: 10.0).repeatForever(autoreverses: true)) {
            positions = positions.map { (position, size, color, opacity) in
                let newX = position.x + CGFloat.random(in: -30...30)
                let newY = position.y + CGFloat.random(in: -30...30)
                return (CGPoint(x: newX, y: newY), size, color, opacity)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LoadingScreen { _ in
        // xprint("Splash complete!")
    }
}
