//
//  IntelligenceLoadingView.swift
//  BigWarRoom
//
//  Animated loading view for Intelligence dashboard with glowing orbs
//

import SwiftUI

/// Animated loading view with multi-colored glowing orbs and engaging copy
struct IntelligenceLoadingView: View {
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var loadingTextIndex: Int = 0
    
    // Loading messages that cycle
    private let loadingMessages = [
        "Gathering data from all your leagues...",
        "Analyzing opponent lineups...",
		"This is a LOT of data... almost there!",
        "Calculating threat levels...",
        "This will be worth it...",
        "Processing injury reports...",
        "Cross-referencing player conflicts...",
        "Building strategic insights...",
        "Making sense of it all...",
        "Final calculations... worth the wait!"
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            // Move content up by reducing top spacer
//            Spacer()
//                .frame(maxHeight: 100) // Limit the top spacer

            // Animated orb cluster
            animatedOrbCluster
            
            // Loading text
            loadingText
            
            // Larger bottom spacer to push content up
            Spacer()
                .frame(maxHeight: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimations()
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
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // Orbiting orbs
            ForEach(0..<8, id: \.self) { index in
                orb(for: index)
            }
            
            // Central core orb
            centralOrb
        }
        .rotationEffect(.degrees(rotationAngle))
        .animation(.linear(duration: 8.0).repeatForever(autoreverses: false), value: rotationAngle)
    }
    
    private func orb(for index: Int) -> some View {
        let angle = Double(index) * 45.0 // 360/8 = 45 degrees apart
        let radius: CGFloat = 60
        let x = cos(angle * .pi / 180) * radius
        let y = sin(angle * .pi / 180) * radius
        
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orbColor(for: index),
                        orbColor(for: index).opacity(0.6),
                        orbColor(for: index).opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 15
                )
            )
            .frame(width: 20, height: 20)
            .offset(x: x, y: y)
            .scaleEffect(pulseAnimation ? 1.3 : 0.7)
            .animation(
                .easeInOut(duration: 1.5)
                .delay(Double(index) * 0.1)
                .repeatForever(autoreverses: true),
                value: pulseAnimation
            )
            .shadow(color: orbColor(for: index), radius: 10, x: 0, y: 0)
    }
    
    private var centralOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color.blue.opacity(0.8),
                        Color.purple.opacity(0.6),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 5,
                    endRadius: 25
                )
            )
            .frame(width: 40, height: 40)
            .scaleEffect(pulseAnimation ? 1.4 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
            .shadow(color: .white, radius: 15, x: 0, y: 0)
    }
    
    private func orbColor(for index: Int) -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan
        ]
        return colors[index % colors.count]
    }
    
    // MARK: - Loading Text
    
    private var loadingText: some View {
        VStack(spacing: 12) {
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationOffset == CGFloat(index) ? 1.5 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .delay(Double(index) * 0.2)
                            .repeatForever(autoreverses: true),
                            value: animationOffset
                        )
                }
            }
            .padding(.bottom, 8)
            
            // Main loading message
            Text(loadingMessages[loadingTextIndex])
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.5), value: loadingTextIndex)
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        // Start pulse animation
        pulseAnimation = true
        
        // Start rotation
        rotationAngle = 360
        
        // Start dot animation
        withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
            animationOffset = 2
        }
        
        // Cycle through loading messages
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                loadingTextIndex = (loadingTextIndex + 1) % loadingMessages.count
            }
        }
    }
}

// MARK: - Helper Methods
    
    // private func getCurrentTaskCount() -> String {
    //     // Simulate increasing data processing
    //     let baseCounts = [247, 391, 528, 612, 745, 889, 934, 1067, 1249]
    //     let currentCount = baseCounts[min(loadingTextIndex, baseCounts.count - 1)]
    //     return String(currentCount)
    // }

// MARK: - Preview

#Preview("Intelligence Loading") {
    ZStack {
        Image("BG2")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.4)
            .ignoresSafeArea(.all)
        
        IntelligenceLoadingView()
    }
    .preferredColorScheme(.dark)
}
