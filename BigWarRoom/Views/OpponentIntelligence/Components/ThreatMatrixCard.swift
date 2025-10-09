//
//  ThreatMatrixCard.swift
//  BigWarRoom
//
//  Threat assessment card for opponent intelligence
//

import SwiftUI

/// Card displaying opponent threat analysis for a single league matchup
struct ThreatMatrixCard: View {
    let intelligence: OpponentIntelligence
    let onTap: () -> Void
    
    // FIXED: Each card gets its own animation state with unique ID
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Threat level indicator with critical animation
                VStack(spacing: 4) {
                    // Animated threat circle for critical level
                    ZStack {
                        // Orange shadow/glow for critical threats only - CHANGED from gpGreen to gpOrange
                        if intelligence.threatLevel == .critical {
                            Circle()
                                .fill(Color.gpOrange.opacity(0.6))
                                .frame(width: isPulsing ? 32 : 28, height: isPulsing ? 32 : 28)
                                .blur(radius: 4)
                                .scaleEffect(isPulsing ? 1.3 : 1.0)
                                .opacity(isPulsing ? 0.8 : 0.4)
                        }
                        
                        // Main threat level circle
                        Circle()
                            .fill(intelligence.threatLevel.color)
                            .frame(width: 20, height: 20)
                            .scaleEffect(intelligence.threatLevel == .critical ? (isPulsing ? 1.2 : 1.0) : 1.0)
                        
                        // Emoji
                        Text(intelligence.threatLevel.emoji)
                            .font(.system(size: intelligence.threatLevel == .critical ? 16 : 14))
                    }
                    .onAppear {
                        // FIXED: Only animate critical threats with unique timing per card
                        if intelligence.threatLevel == .critical {
                            // Add slight delay based on card ID to prevent sync
                            let delay = Double(intelligence.id.hash % 500) / 1000.0 // 0-0.5 second delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                withAnimation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true)
                                ) {
                                    isPulsing = true
                                }
                            }
                        }
                    }
                    
                    Text(intelligence.threatLevel.rawValue)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(intelligence.threatLevel.color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(intelligence.threatLevel.color.opacity(0.2))
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 65)
                
                // League and opponent info
                VStack(alignment: .leading, spacing: 6) {
                    // League name
                    HStack {
                        Text(intelligence.leagueName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // League source logo - REPLACED text with actual logos
                        Group {
                            if intelligence.leagueSource == .espn {
                                Image("espnLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image("sleeperLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    
                    // Opponent name
                    Text(intelligence.opponentTeam.ownerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Score comparison
                    HStack {
                        Text("You: \(intelligence.myTeam.currentScore?.formatted(.number.precision(.fractionLength(1))) ?? "0.0")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(intelligence.isLosingTo ? .red : .green)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text("Them: \(intelligence.totalOpponentScore.formatted(.number.precision(.fractionLength(1))))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(intelligence.isLosingTo ? .green : .red)
                        
                        Spacer()
                        
                        // Score differential
                        let diff = intelligence.scoreDifferential
                        Text(diff >= 0 ? "+\(diff.formatted(.number.precision(.fractionLength(1))))" : "\(diff.formatted(.number.precision(.fractionLength(1))))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(diff >= 0 ? .green : .red)
                    }
                }
                
                // Top threat player
                if let topThreat = intelligence.topThreatPlayer {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("TOP THREAT")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.gray)
                        
                        Text(topThreat.playerName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.trailing)
                        
                        Text("\(topThreat.scoreDisplay) pts")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(topThreat.threatLevel.color)
                    }
                    .frame(width: 80)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(intelligence.threatLevel.color.opacity(0.5), lineWidth: 1)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                intelligence.threatLevel.color.opacity(0.1),
                                intelligence.threatLevel.color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}