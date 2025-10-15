//
//  RecommendationCard.swift
//  BigWarRoom
//
//  Strategic recommendation card for opponent intelligence
//

import SwiftUI

/// Card displaying strategic recommendations based on opponent analysis
struct RecommendationCard: View {
    let recommendation: StrategicRecommendation
    
    // Check if this is a Critical Threat Alert
    private var isCriticalThreatAlert: Bool {
        recommendation.title.contains("Critical Threat Alert") && recommendation.priority == .critical
    }
    
    // Check if this is a Player Conflict Detected
    private var isPlayerConflict: Bool {
        recommendation.title.contains("Player Conflict Detected")
    }
    
    // Animation state for pulsing effect
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator with opponent avatar for Critical Threat Alerts
            VStack(spacing: 4) {
                if isCriticalThreatAlert, let opponentTeam = recommendation.opponentTeam {
                    // Opponent avatar with pulsing animation (like Threat Matrix)
                    ZStack {
                        // Pulsing glow for critical threats
                        Circle()
                            .fill(Color.gpRedPink.opacity(0.6))
                            .frame(width: isPulsing ? 44 : 40, height: isPulsing ? 44 : 40)
                            .blur(radius: 4)
                            .scaleEffect(isPulsing ? 1.2 : 1.0)
                            .opacity(isPulsing ? 0.8 : 0.4)
                        
                        // Opponent avatar
                        if let avatarURL = opponentTeam.avatarURL {
                            AsyncImage(url: avatarURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(opponentTeam.teamInitials)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                        } else {
                            // Fallback: team initials in circle
                            Circle()
                                .fill(opponentTeam.espnTeamColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(opponentTeam.teamInitials)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .onAppear {
                        // Start pulsing animation for critical threats
                        let delay = Double(recommendation.id.hashValue % 500) / 1000.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            withAnimation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                            ) {
                                isPulsing = true
                            }
                        }
                    }
                } else {
                    // Regular priority indicator for other recommendations
                    Image(systemName: recommendation.type.sfSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(recommendation.priority.color)
                    
                    Circle()
                        .fill(recommendation.priority.color)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 40)
            
            // Recommendation content
            VStack(alignment: .leading, spacing: 6) {
                // Title with special styling for Critical Threat Alert
                if isCriticalThreatAlert {
                    // Special container for Critical Threat Alert title (like WEEK picker)
                    HStack(spacing: 6) {
                        Text(recommendation.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Alert badge
                        Text("ALERT")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gpRedPink.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gpRedPink, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.gpRedPink.opacity(0.3),
                                        Color.gpRedPink.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gpRedPink.opacity(0.6), lineWidth: 1)
                            )
                    )
                } else if isPlayerConflict {
                    // Special container for Player Conflict Detected (gpPink styling)
                    HStack(spacing: 6) {
                        Text(recommendation.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Conflict badge
                        Text("CONFLICT")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gpPink.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gpPink, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.gpPink.opacity(0.3),
                                        Color.gpPink.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gpPink.opacity(0.6), lineWidth: 1)
                            )
                    )
                } else {
                    // Regular title for other recommendations
                    Text(recommendation.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                // Description
                Text(recommendation.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Actionable indicator
            if recommendation.actionable && !isCriticalThreatAlert && !isPlayerConflict {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    
                    Text("ACTION")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(12)
        .background(
            // Blur backdrop layer
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial) // iOS blur material
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2)) // Light tint for transparency
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isCriticalThreatAlert ? Color.gpRedPink.opacity(0.7) : 
                            isPlayerConflict ? Color.gpPink.opacity(0.7) :
                            recommendation.priority.color.opacity(0.5), 
                            lineWidth: (isCriticalThreatAlert || isPlayerConflict) ? 2 : 1
                        )
                )
        )
        .background(
            // Outer glow effect
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: isCriticalThreatAlert ? [
                            Color.gpRedPink.opacity(0.15),
                            Color.gpRedPink.opacity(0.05)
                        ] : isPlayerConflict ? [
                            Color.gpPink.opacity(0.15),
                            Color.gpPink.opacity(0.05)
                        ] : [
                            recommendation.priority.color.opacity(0.1),
                            recommendation.priority.color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 1)
        )
    }
}