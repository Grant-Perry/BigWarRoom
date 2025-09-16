//
//  MatchupsHubLoadingHeroAnimationView.swift
//  BigWarRoom
//
//  Hero loading animation component for MatchupsHubLoadingIndicator
//

import SwiftUI

/// Hero loading animation with animated gradient rings and football
struct MatchupsHubLoadingHeroAnimationView: View {
    let rotation: Double
    let scale: Double
    let opacity: Double
    let pulseScale: Double
    
    var body: some View {
        ZStack {
            // Animated gradient rings
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.6), .blue.opacity(0.4), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(3 - index)
                    )
                    .frame(width: CGFloat(100 + index * 25))
                    .rotationEffect(.degrees(rotation + Double(index * 45)))
                    .opacity(opacity - Double(index) * 0.15)
            }
            
            // Central football with glow
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
}