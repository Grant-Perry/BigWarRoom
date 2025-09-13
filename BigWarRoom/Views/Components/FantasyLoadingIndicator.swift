//
//  FantasyLoadingIndicator.swift
//  BigWarRoom
//
//  Clean animated loading indicator for Fantasy matchups
//

import SwiftUI

struct FantasyLoadingIndicator: View {
    @State private var rotation: Double = 0
    @State private var pulseScale: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Just the clean spinning football - that's it!
            ZStack {
                // Subtle animated rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.gpGreen.opacity(0.4), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(60 + index * 20))
                        .rotationEffect(.degrees(rotation + Double(index * 60)))
                        .opacity(0.6 - Double(index) * 0.15)
                }
                
                // Central football with glow
                ZStack {
                    // Subtle glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.gpGreen.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(pulseScale)
                    
                    // Football background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brown, Color.brown.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    // Football icon
                    Image(systemName: "football.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotation * 0.5))
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Subtle pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
}

// MARK: -> Preview
#Preview {
    FantasyLoadingIndicator()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}