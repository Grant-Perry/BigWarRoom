//
//  CentralizedLoadingView.swift
//  BigWarRoom
//
//  Centralized app loading screen with spinning orbs
//

import SwiftUI

struct CentralizedLoadingView: View {
    @ObservedObject var loader: CentralizedAppLoader
    @StateObject private var sharedStats = SharedStatsService.shared  // 🔥 NEW: Monitor stats loading
    
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Bool = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Image("BG7")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.35)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 40) {
                Spacer()
                
                // App branding
                VStack(spacing: 16) {
                    Text("BigWarRoom")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    // 🔥 NEW: Dynamic loading message based on progress
                    Text(dynamicLoadingMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .animation(.easeInOut(duration: 0.3), value: dynamicLoadingMessage)
                }
                
                // Animated orb cluster
                animatedOrbCluster
                
                // Loading progress and message
                VStack(spacing: 16) {
                    // Progress bar
                    VStack(spacing: 8) {
                        ProgressView(value: loader.loadingProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: progressBarColor))
                            .scaleEffect(y: 2.0)
                            .frame(width: 250)
                        
                        Text("\(Int(loader.loadingProgress * 100))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(progressColor(for: loader.loadingProgress))
                            .animation(.easeInOut(duration: 0.3), value: loader.loadingProgress)
                    }
                    
                    // Current loading message
                    Text(loader.currentLoadingMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: loader.currentLoadingMessage)
                    
                    // 🔥 NEW: Show stats loading status
                    if sharedStats.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            
                            Text("Loading player stats...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    } else if loader.canShowPartialData && loader.loadingProgress > 0.4 {
                        Text("Ready to show data")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Version info
                Text("Version: \(AppConstants.getVersion())")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // 🔥 NEW: Dynamic loading message based on progress
    private var dynamicLoadingMessage: String {
        switch loader.loadingProgress {
        case 0.0..<0.2:
            return "Starting up..."
        case 0.2..<0.4:
            return sharedStats.isLoading ? "Loading shared stats..." : "Preparing data..."
        case 0.4..<0.8:
            return "Loading leagues..."
        case 0.8..<1.0:
            return "Finalizing..."
        default:
            return loader.canShowPartialData ? "Ready!" : "Loading your fantasy data..."
        }
    }
    
    // 🔥 NEW: Progress bar color changes with loading stage
    private var progressBarColor: Color {
        switch loader.loadingProgress {
        case 0.0..<0.4:
            return .blue
        case 0.4..<0.8:
            return .orange
        default:
            return .green
        }
    }
    
    // MARK: - Animated Orb Cluster
    
    private var animatedOrbCluster: some View {
        ZStack {
            // Background glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.4),
                            Color.purple.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(pulseAnimation ? 1.3 : 0.9)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // Orbiting orbs
            ForEach(0..<8, id: \.self) { index in
                orb(for: index)
            }
            
            // Central core orb
            centralOrb
        }
        .rotationEffect(.degrees(rotationAngle))
        .animation(.linear(duration: 10.0).repeatForever(autoreverses: false), value: rotationAngle)
    }
    
    private func orb(for index: Int) -> some View {
        let angle = Double(index) * 45.0 // 360/8 = 45 degrees apart
        let radius: CGFloat = 70
        let x = cos(angle * .pi / 180) * radius
        let y = sin(angle * .pi / 180) * radius
        
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orbColor(for: index),
                        orbColor(for: index).opacity(0.7),
                        orbColor(for: index).opacity(0.3),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 18
                )
            )
            .frame(width: 24, height: 24)
            .offset(x: x, y: y)
            .scaleEffect(pulseAnimation ? 1.4 : 0.8)
            .animation(
                .easeInOut(duration: 1.8)
                .delay(Double(index) * 0.12)
                .repeatForever(autoreverses: true),
                value: pulseAnimation
            )
            .shadow(color: orbColor(for: index), radius: 12, x: 0, y: 0)
    }
    
    private var centralOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color.blue.opacity(0.9),
                        Color.purple.opacity(0.7),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 5,
                    endRadius: 30
                )
            )
            .frame(width: 50, height: 50)
            .scaleEffect(pulseAnimation ? 1.5 : 1.1)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
            .shadow(color: .white, radius: 20, x: 0, y: 0)
    }
    
    private func orbColor(for index: Int) -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan
        ]
        return colors[index % colors.count]
    }
    
    // MARK: - Progress Color Helper
    
    private func progressColor(for progress: Double) -> Color {
        // Interpolate from red (0%) to green (100%)
        let normalizedProgress = max(0, min(1, progress)) // Clamp between 0 and 1
        
        if normalizedProgress < 0.5 {
            // 0% to 50%: Red to Yellow
            let factor = normalizedProgress * 2 // 0 to 1
            return Color.red.interpolated(with: .yellow, by: factor)
        } else {
            // 50% to 100%: Yellow to Green
            let factor = (normalizedProgress - 0.5) * 2 // 0 to 1
            return Color.yellow.interpolated(with: .green, by: factor)
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        pulseAnimation = true
        rotationAngle = 360
        
        withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
            animationOffset = 2
        }
    }
}

#Preview {
    CentralizedLoadingView(loader: CentralizedAppLoader.shared)
        .preferredColorScheme(.dark)
}

// MARK: - Color Extension for Interpolation
extension Color {
    func interpolated(with color: Color, by factor: Double) -> Color {
        let factor = max(0, min(1, factor)) // Clamp factor between 0 and 1
        
        // Convert SwiftUI Colors to UIColors for easier interpolation
        let uiColor1 = UIColor(self)
        let uiColor2 = UIColor(color)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * factor
        let g = g1 + (g2 - g1) * factor
        let b = b1 + (b2 - b1) * factor
        let a = a1 + (a2 - a1) * factor
        
        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}