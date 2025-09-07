//
//  FantasyLoadingIndicator.swift
//  BigWarRoom
//
//  Cool animated loading indicator for Fantasy matchups - Dark Theme
//

import SwiftUI

struct FantasyLoadingIndicator: View {
    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0
    @State private var opacity: Double = 0.8
    @State private var pulseScale: Double = 1.0
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            // Hero loading animation (Dark theme)
            heroLoadingAnimation
            
            // Fantasy matchup loading message
            fantasyLoadingMessage
            
            // Progress bar with shimmer
            overallProgressBar
        }
        .padding(.horizontal, 24)
        .onAppear {
            startAnimations()
        }
    }
    
    private var heroLoadingAnimation: some View {
        ZStack {
            // Animated gradient rings (Dark green theme)
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.6), .gray.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(3 - index)
                    )
                    .frame(width: CGFloat(100 + index * 25))
                    .rotationEffect(.degrees(rotation + Double(index * 45)))
                    .opacity(opacity - Double(index) * 0.15)
            }
            
            // Central football with glow (Dark theme)
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.gpGreen.opacity(0.8), .clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                
                // Football background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brown.opacity(0.9), Color.brown.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(scale)
                
                // Football icon
                Image(systemName: "football.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation * 0.5))
            }
        }
    }
    
    private var fantasyLoadingMessage: some View {
        VStack(spacing: 16) {
            // Dark theme header
            VStack(spacing: 8) {
                Text("FANTASY COMMAND")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gpGreen, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Loading Weekly Battles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            // Animated status messages
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Status icon
                    Text("⚡")
                        .font(.system(size: 16))
                        .scaleEffect(pulseScale * 0.8)
                    
                    Text("Analyzing matchup data...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var overallProgressBar: some View {
        VStack(spacing: 12) {
            // Progress bar (Dark theme)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)
                    
                    // Progress fill with dark gradient
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.gpGreen, .gpGreen.opacity(0.7), .gray.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0.05, progress), height: 12)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 12)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * progress))
                        .animation(
                            .linear(duration: 2.0).repeatForever(autoreverses: false),
                            value: progress
                        )
                }
            }
            .frame(height: 12)
            
            // Progress text
            HStack {
                Text("Preparing your fantasy battles...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.gpGreen)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(maxWidth: 300)
    }
    
    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
            opacity = 1.0
        }
        
        // Scale breathing
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            scale = 1.15
        }
        
        // Progress simulation
        withAnimation(.easeInOut(duration: 2.5)) {
            progress = 1.0
        }
    }
}

// MARK: -> Preview
#Preview {
    FantasyLoadingIndicator()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}