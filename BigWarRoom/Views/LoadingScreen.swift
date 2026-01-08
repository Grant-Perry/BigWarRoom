//
//  LoadingScreen.swift
//  BigWarRoom
//
//  Beautiful splash screen with purple/blue gradients, bokeh effects, and spinning football
//

import SwiftUI

struct LoadingScreen: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.5
    @State private var logoGlow: CGFloat = 0.3
    @State private var textOpacity: Double = 0.0
    @State private var purpleWave: CGFloat = 0
    @State private var isComplete = false
    @State private var footballScale: Double = 1.0
    @State private var loadingMessage = "Loading BigWarRoom..." // 🔥 NEW: Loading progress message
    @State private var isDataLoading = false // 🔥 NEW: Track data loading state
    @State private var orbRotation: Double = 0 // 🔥 NEW: For spinning orbs
    
    /// Completion handler 
    let onComplete: (Bool) -> Void
    
    /// 🔥 PHASE 2.5: Accept dependencies instead of using .shared
    private let espnCredentials: ESPNCredentialsManager
    private let sleeperCredentials: SleeperCredentialsManager
    private let matchupsHub: MatchupsHubViewModel
    
    // 🔥 PHASE 2.5: Dependency injection initializer
    init(
        onComplete: @escaping (Bool) -> Void,
        espnCredentials: ESPNCredentialsManager,
        sleeperCredentials: SleeperCredentialsManager,
        matchupsHub: MatchupsHubViewModel
    ) {
        self.onComplete = onComplete
        self.espnCredentials = espnCredentials
        self.sleeperCredentials = sleeperCredentials
        self.matchupsHub = matchupsHub
    }

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
            
            // 🔥 FIXED: Use standalone SpinningOrbsView component
            SpinningOrbsView()
                .opacity(textOpacity)
            
            // Main content
            VStack(spacing: 50) {
                Spacer()
                
                // Spinning Football Animation with version underneath
                VStack(spacing: 12) {
                    SpinningFootballView()
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale)
                        .shadow(color: .purple.opacity(logoGlow), radius: 20, x: 0, y: 0)
                        .shadow(color: .blue.opacity(logoGlow * 0.8), radius: 30, x: 0, y: 0)
                        .animation(.spring(response: 1.5, dampingFraction: 0.8), value: scale)
                        .animation(.easeInOut(duration: 2.0), value: logoGlow)
                    
                    // Version under the football
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
                
                // 🔥 NEW: Loading message and progress
                VStack(spacing: 16) {
                    LoadingDots()
                        .opacity(textOpacity)
                    
                    Text(loadingMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(textOpacity)
                        .animation(.easeInOut(duration: 0.3), value: loadingMessage)
                    
                    // 🔥 NEW: Show different message when data loading vs splash
                    if isDataLoading {
                        Text("Loading your leagues...")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .opacity(textOpacity)
                    } else {
                        Text("Tap to continue")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .opacity(textOpacity)
                            .animation(.easeIn(duration: 1.0).delay(2.0), value: textOpacity)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onTapGesture {
            // Only allow tap to skip if not loading data
            if !isDataLoading {
                completeLoading()
            }
        }
        .onAppear {
            startSplashSequence()
            startOrbAnimation()
        }
        .onChange(of: matchupsHub.currentLoadingLeague) { _, newMessage in
            if !newMessage.isEmpty && isDataLoading {
                loadingMessage = newMessage
            }
        }
    }
    
    /// 🔥 NEW: Start the spinning orbs animation
    private func startOrbAnimation() {
        withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
            orbRotation = 360
        }
    }
    
    /// Starts the beautiful splash animation sequence
    private func startSplashSequence() {
        // Grow the football
        withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.3)) {
            scale = 1.0
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
        
        // 🔥 REMOVED FORCED DELAY: Start loading immediately after animations begin
        startEssentialDataLoading()
    }
    
    /// 🔥 NEW: Load essential data before showing main app
    private func startEssentialDataLoading() {
        DebugPrint(mode: .appLoad, "🚀 LoadingScreen.startEssentialDataLoading - START at \(Date())")
        
        // Check if user has any valid credentials
        let hasESPNCredentials = espnCredentials.hasValidCredentials
        let hasSleeperCredentials = sleeperCredentials.hasValidCredentials
        let hasAnyCredentials = hasESPNCredentials || hasSleeperCredentials
        
        DebugPrint(mode: .appLoad, "🔐 LoadingScreen: hasESPN=\(hasESPNCredentials), hasSleeper=\(hasSleeperCredentials)")
        
        // If no credentials, skip data loading and go straight to onboarding
        if !hasAnyCredentials {
            DebugPrint(mode: .appLoad, "⏭️ LoadingScreen: No credentials, skipping to onboarding")
            completeLoading()
            return
        }
        
        // Start loading essential data
        isDataLoading = true
        loadingMessage = "Loading your leagues..."
        
        DebugPrint(mode: .appLoad, "📦 LoadingScreen: Starting matchupsHub.loadAllMatchups at \(Date())")
        
        Task {
            let startTime = Date()
            
            // Load the essential Mission Control data
            await matchupsHub.loadAllMatchups()
            
            let loadDuration = Date().timeIntervalSince(startTime)
            DebugPrint(mode: .appLoad, "✅ LoadingScreen: loadAllMatchups completed in \(String(format: "%.2f", loadDuration))s")
            
            // TODO: Update this when AllLivePlayersViewModel.shared is eliminated
            // await AllLivePlayersViewModel.shared.loadAllPlayers()
            
            
            await MainActor.run {
                DebugPrint(mode: .appLoad, "🏁 LoadingScreen: Calling completeLoading at \(Date())")
                completeLoading()
            }
        }
    }
    
    /// Checks if user has persistent data and completes loading
    private func completeLoading() {
        DebugPrint(mode: .appLoad, "🎬 LoadingScreen.completeLoading - START at \(Date())")
        
        guard !isComplete else { 
            DebugPrint(mode: .appLoad, "⚠️ LoadingScreen.completeLoading - ALREADY COMPLETE, ignoring")
            return 
        }
        isComplete = true
        
        // Check if user has any valid credentials setup
        let hasESPNCredentials = espnCredentials.hasValidCredentials
        let hasSleeperCredentials = sleeperCredentials.hasValidCredentials
        
        // If user has EITHER ESPN OR Sleeper credentials, skip onboarding
        let hasAnyCredentials = hasESPNCredentials || hasSleeperCredentials
        
        DebugPrint(mode: .appLoad, "🔐 LoadingScreen.completeLoading: hasCredentials=\(hasAnyCredentials)")
        
        withAnimation(.easeInOut(duration: 0.5)) {
            // Add exit animation here if needed
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Only show onboarding if NO credentials exist
            let shouldShowOnboarding = !hasAnyCredentials
            DebugPrint(mode: .appLoad, "🏁 LoadingScreen: Loading complete - showing onboarding: \(shouldShowOnboarding)")
            onComplete(shouldShowOnboarding)
        }
    }
}

// MARK: - Spinning Football View

struct SpinningFootballView: View {
    @State private var rotation: Double = 0
    @State private var footballScale: Double = 1.0
    @State private var glowOpacity: Double = 0.8
    
    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gpGreen.opacity(0.2))
                    .frame(width: 120 + CGFloat(index * 20))
                    .blur(radius: CGFloat(5 + index * 3))
                    .opacity(glowOpacity * (1.0 - Double(index) * 0.2))
                    .animation(
                        .easeInOut(duration: 2.0 + Double(index) * 0.5)
                        .repeatForever(autoreverses: true),
                        value: glowOpacity
                    )
            }
            
            // Main football circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.brown, .brown.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .scaleEffect(footballScale)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: footballScale
                )
            
            // Football icon that rotates
            Image(systemName: "football.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .rotationEffect(.degrees(rotation))
                .animation(
                    .linear(duration: 3.0)
                    .repeatForever(autoreverses: false),
                    value: rotation
                )
            
            // Loading dots around the football
            ForEach(0..<8) { index in
                Circle()
                    .fill(Color.gpGreen)
                    .frame(width: 8, height: 8)
                    .offset(y: -50)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .opacity(loadingDotOpacity(for: index))
                    .animation(
                        .linear(duration: 1.0)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.125),
                        value: rotation
                    )
            }
        }
        .onAppear {
            startFootballAnimations()
        }
    }
    
    private func startFootballAnimations() {
        withAnimation {
            rotation = 360
            footballScale = 1.2
            glowOpacity = 1.0
        }
        
        // Continuous rotation
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.linear(duration: 3.0)) {
                rotation += 360
            }
        }
    }
    
    private func loadingDotOpacity(for index: Int) -> Double {
        let progress = (rotation / 360.0).truncatingRemainder(dividingBy: 1.0)
        let dotProgress = (progress * 8 - Double(index)).truncatingRemainder(dividingBy: 8.0)
        return dotProgress < 1.0 ? 1.0 : 0.3
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