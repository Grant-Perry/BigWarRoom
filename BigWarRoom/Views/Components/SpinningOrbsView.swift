//
//  SpinningOrbsView.swift
//  BigWarRoom
//
//  🔥 PROPER: Reusable spinning orbs animation extracted from original working code
//

import SwiftUI

struct SpinningOrbsView: View {
    @State private var pulseAnimation: Bool = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background glow effect - matches original
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
            
            // Orbiting orbs - exactly like the original
            ForEach(0..<8, id: \.self) { index in
                orb(for: index)
            }
            
            // Central core orb
            centralOrb
        }
        .rotationEffect(.degrees(rotationAngle))
        .animation(.linear(duration: 10.0).repeatForever(autoreverses: false), value: rotationAngle)
        .onAppear {
            startAnimations()
        }
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
    
    private func startAnimations() {
        pulseAnimation = true
        rotationAngle = 360
    }
}