//
//  MatchupsHubView+EmptyState.swift
//  BigWarRoom
//
//  Epic animated empty state for MatchupsHubView
//

import SwiftUI

// MARK: - Empty State
extension MatchupsHubView {
    
    var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 🔥 HERO ANIMATION SECTION
            VStack(spacing: 24) {
                heroAnimationSection
                dramaticTextSection
            }
            
            Spacer()
            
            // 🔥 EPIC CTA BUTTON SECTION
            ctaButtonSection
            
            Spacer()
        }
        .background(animatedBackgroundParticles)
    }
    
    // MARK: - Hero Animation Section
    private var heroAnimationSection: some View {
        ZStack {
            // Outer glow rings (animated with enhanced pulsing)
            ForEach(0..<3) { index in
                glowRing(index: index)
            }
            
            // Inner pulsing energy ring
            innerEnergyRing
            
            // Central pulsing gradient background (enhanced)
            centralGradientBackground
            
            // Main football icon with glow (fixed position as requested)
            footballIcon
        }
    }
    
    private func glowRing(index: Int) -> some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [.gpGreen.opacity(0.9), .blue.opacity(0.7), .purple.opacity(0.5), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
            .frame(width: CGFloat(120 + index * 40), height: CGFloat(120 + index * 40))
            .opacity(0.6 - Double(index) * 0.15)
            .scaleEffect(0.8 + sin(Date().timeIntervalSince1970 * 1.5 + Double(index) * 0.8) * 0.3)
            .rotationEffect(.degrees(Date().timeIntervalSince1970 * 10 + Double(index) * 30))
            .shadow(color: .gpGreen.opacity(0.4), radius: 8 + CGFloat(index * 4), x: 0, y: 0)
            .shadow(color: .blue.opacity(0.3), radius: 15 + CGFloat(index * 6), x: 0, y: 0)
            .animation(.easeInOut(duration: 3 + Double(index) * 0.7).repeatForever(autoreverses: true), value: Date())
    }
    
    private var innerEnergyRing: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.8), .gpGreen, .blue, .white.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
            .frame(width: 100, height: 100)
            .opacity(0.8)
            .scaleEffect(0.9 + sin(Date().timeIntervalSince1970 * 2.5) * 0.15)
            .rotationEffect(.degrees(-Date().timeIntervalSince1970 * 15))
            .shadow(color: .white.opacity(0.6), radius: 12, x: 0, y: 0)
            .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: Date())
    }
    
    private var centralGradientBackground: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .gpGreen.opacity(0.8),
                        .blue.opacity(0.6),
                        .purple.opacity(0.4),
                        .clear
                    ],
                    center: .center,
                    startRadius: 15,
                    endRadius: 90
                )
            )
            .frame(width: 120, height: 120)
            .scaleEffect(1.1 + sin(Date().timeIntervalSince1970 * 1.8) * 0.2)
            .blur(radius: 10)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: Date())
    }
    
    private var footballIcon: some View {
        Image(systemName: "football")
            .font(.system(size: 50, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .gpGreen, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .gpGreen, radius: 15, x: 0, y: 0)
            .shadow(color: .blue, radius: 25, x: 0, y: 0)
            .shadow(color: .white, radius: 8, x: 0, y: 0)
    }
    
    // MARK: - Dramatic Text Section
    private var dramaticTextSection: some View {
        VStack(spacing: 16) {
            // Main title with animated gradient
            Text("NO ACTIVE BATTLES")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .gpGreen, .blue, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(1 + sin(Date().timeIntervalSince1970 * 2) * 0.05)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: Date())
            
            // Subtitle with typewriter effect styling
            VStack(spacing: 8) {
                Text("Your fantasy leagues are waiting")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray.opacity(0.9))
                
                Text("Connect now and dominate the competition")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.8), .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - CTA Button Section
    private var ctaButtonSection: some View {
        VStack(spacing: 20) {
            // Floating particles around button area
            ZStack {
                floatingParticles
                mainCtaButton
            }
            .frame(height: 80)
            
            // Subtle hint text
            Text("ESPN • Sleeper • More platforms coming")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gray.opacity(0.8), .gpGreen.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.bottom, 20)
        }
    }
    
    private var floatingParticles: some View {
        ForEach(0..<6) { index in
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.gpGreen, .blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 4, height: 4)
                .offset(
                    x: cos(Date().timeIntervalSince1970 * 1.5 + Double(index) * 1.047) * 60,
                    y: sin(Date().timeIntervalSince1970 * 1.5 + Double(index) * 1.047) * 30
                )
                .opacity(0.7)
                .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: Date())
        }
    }
    
    private var mainCtaButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            HStack(spacing: 12) {
                // Animated plus icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(1 + sin(Date().timeIntervalSince1970 * 3) * 0.1)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: Date())
                }
                
                Text("CONNECT LEAGUES")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1)
                
                // Animated arrow
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .offset(x: sin(Date().timeIntervalSince1970 * 4) * 3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: Date())
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(ctaButtonBackground)
            .scaleEffect(1 + sin(Date().timeIntervalSince1970 * 2.5) * 0.03)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: Date())
        }
    }
    
    private var ctaButtonBackground: some View {
        ZStack {
            // Base gradient
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [.gpGreen, .blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Animated shimmer overlay
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .clear, .white.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .offset(x: sin(Date().timeIntervalSince1970 * 2) * 20)
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: Date())
            
            // Glow effect
            RoundedRectangle(cornerRadius: 30)
                .fill(.clear)
                .shadow(color: .gpGreen.opacity(0.5), radius: 15, x: 0, y: 0)
                .shadow(color: .blue.opacity(0.5), radius: 25, x: 0, y: 5)
        }
    }
    
    // MARK: - Animated Background Particles
    private var animatedBackgroundParticles: some View {
        ZStack {
            ForEach(0..<15) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.1), .blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: CGFloat.random(in: 2...8),
                        height: CGFloat.random(in: 2...8)
                    )
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height) + sin(Date().timeIntervalSince1970 * 0.5 + Double(index)) * 50
                    )
                    .animation(.linear(duration: Double.random(in: 8...15)).repeatForever(autoreverses: false), value: Date())
            }
        }
    }
}