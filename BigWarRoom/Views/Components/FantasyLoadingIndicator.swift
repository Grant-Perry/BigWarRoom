//
//  FantasyLoadingIndicator.swift
//  BigWarRoom
//
//  Cool animated loading indicator for Fantasy matchups
//

import SwiftUI

struct FantasyLoadingIndicator: View {
    @State private var rotation: Double = 0
    @State private var scale: Double = 1
    @State private var opacity: Double = 0.8
    
    var body: some View {
        VStack(spacing: 24) {
            // Main animated football with rotation and pulsing
            footballAnimation
            
            // Text with gradient animation
            loadingText
            
            // Progress bar with animated fill
            ProgressBarView()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private var footballAnimation: some View {
        ZStack {
            // Outer glow rings
            glowRings
            
            // Main football circle background
            footballBackground
            
            // Football icon that rotates
            footballIcon
            
            // Loading dots around the football
            loadingDots
        }
    }
    
    private var glowRings: some View {
        ForEach(0..<3) { index in
            Circle()
                .fill(Color.gpGreen.opacity(0.2))
                .frame(width: 120 + CGFloat(index * 20))
                .blur(radius: CGFloat(5 + index * 3))
                .opacity(opacity * (1.0 - Double(index) * 0.2))
                .animation(
                    .easeInOut(duration: 2.0 + Double(index) * 0.5)
                    .repeatForever(autoreverses: true),
                    value: opacity
                )
        }
    }
    
    private var footballBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.brown, .brown.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
                value: scale
            )
    }
    
    private var footballIcon: some View {
        Image(systemName: "football.fill")
            .font(.system(size: 40))
            .foregroundColor(.white)
            .rotationEffect(.degrees(rotation))
            .animation(
                .linear(duration: 3.0)
                .repeatForever(autoreverses: false),
                value: rotation
            )
    }
    
    private var loadingDots: some View {
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
    
    private var loadingText: some View {
        VStack(spacing: 8) {
            Text("Loading Fantasy Matchups")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Preparing your weekly battles...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gpGreen, .blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(opacity)
                .animation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                    value: opacity
                )
        }
    }
    
    private func startAnimations() {
        withAnimation {
            rotation = 360
            scale = 1.2
            opacity = 1.0
        }
        
        // Slower continuous rotation
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

// MARK: -> Animated Progress Bar
struct ProgressBarView: View {
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    // Animated progress fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.gpGreen, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * progress))
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: progress
                        )
                }
            }
            .frame(height: 8)
            
            // Progress percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gpGreen)
        }
        .frame(maxWidth: 200)
        .onAppear {
            // Simulate loading progress
            withAnimation(.easeInOut(duration: 2.5)) {
                progress = 1.0
            }
        }
    }
}

// MARK: -> Preview
#Preview {
    FantasyLoadingIndicator()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}