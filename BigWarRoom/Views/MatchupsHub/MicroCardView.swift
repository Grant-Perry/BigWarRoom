//
//  MicroCardView.swift
//  BigWarRoom
//
//  DUMB micro card - just displays passed data, no lookups or calculations
//

import SwiftUI

struct MicroCardView: View {
    // DUMB parameters - all data passed in
    let leagueName: String
    let avatarURL: String?
    let managerName: String
    let score: String
    let scoreColor: Color
    let percentage: String
    let borderColors: [Color]
    let borderWidth: CGFloat
    let borderOpacity: Double
    let shouldPulse: Bool
    let shadowColor: Color
    let shadowRadius: CGFloat
    let onTap: () -> Void
    
    @State private var pulseOpacity: Double = 0.3
    @State private var glowIntensity: Double = 0.0
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // League name
                Text(leagueName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                
                // My avatar and manager - FIXED: Show initials immediately
                VStack(spacing: 6) {
                    if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            // SHOW INITIALS IMMEDIATELY - don't wait for avatar
                            Circle()
                                .fill(scoreColor.opacity(0.6)) // Use the team's score color for immediate visual feedback
                                .overlay(
                                    Text(String(managerName.prefix(2)).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        // No avatar URL - show initials with team color
                        Circle()
                            .fill(scoreColor.opacity(0.6)) // Use team color for instant visual feedback
                            .overlay(
                                Text(String(managerName.prefix(2)).uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .frame(width: 36, height: 36)
                    }
                    
                    // Manager name
                    Text(managerName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                // Score - use passed color (SHOWS IMMEDIATELY)
                Text(score)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
                
                // Percentage - use passed color (SHOWS IMMEDIATELY)
                Text(percentage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: borderColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: borderWidth
                            )
                            .opacity(shouldPulse ? pulseOpacity : borderOpacity)
                    )
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if shouldPulse {
                startPulseAnimation()
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.8
            glowIntensity = 0.8
        }
    }
}