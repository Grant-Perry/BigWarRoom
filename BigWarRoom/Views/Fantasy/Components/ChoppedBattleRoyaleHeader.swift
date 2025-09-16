//
//  ChoppedBattleRoyaleHeader.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Battle royale header with dramatic title and week info
struct ChoppedBattleRoyaleHeader: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    let pulseAnimation: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Main title with dramatic effect - USE LEAGUE NAME
            HStack {
                Text("💀")
                    .font(.system(size: 32))
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                
                VStack {
                    Text(choppedLeaderboardViewModel.dramaticLeagueName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .shadow(color: .red.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                
                Text("🔥")
                    .font(.system(size: 32))
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5), value: pulseAnimation)
            }
            
            // WEEK ELIMINATION ROUND HEADER with intense gradients
            VStack(spacing: 8) {
                Text("WEEK \(choppedLeaderboardViewModel.choppedSummary.week)")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .gray, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(2)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Text("ELIMINATION ROUND")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(3)
                    .shadow(color: .red.opacity(0.3), radius: 1, x: 0, y: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.2),
                                Color.black,
                                Color.red.opacity(0.1),
                                Color.black
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.red, .orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                            .opacity(pulseAnimation ? 1.0 : 0.7)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                    )
            )
            
            // Week and survival info with enhanced backgrounds
            HStack(spacing: 8) {
                // SURVIVORS stat card with green gradient
                ChoppedCompactStatCard(
                    title: "SURVIVORS",
                    value: choppedLeaderboardViewModel.survivorsCount,
                    subtitle: "TEAMS",
                    color: .green
                )
                
                // Red separator with glow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .red, .red, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: 40)
                    .shadow(color: .red.opacity(0.6), radius: 2, x: 0, y: 0)
                
                // ELIMINATED stat card with red gradient
                ChoppedCompactStatCard(
                    title: "ELIMINATED",
                    value: choppedLeaderboardViewModel.eliminatedCount,
                    subtitle: "TEAMS",
                    color: .red
                )
            }
            
            // Show pre-game message if week hasn't started with enhanced styling
            if !choppedLeaderboardViewModel.hasWeekStarted {
                HStack(spacing: 8) {
                    Text("⏰")
                        .font(.system(size: 16))
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Text("GAMES HAVEN'T STARTED YET")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(1)
                    
                    Text("⏰")
                        .font(.system(size: 16))
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.3), value: pulseAnimation)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.2),
                                    Color.yellow.opacity(0.1),
                                    Color.orange.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange, .yellow, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .opacity(pulseAnimation ? 1.0 : 0.6)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                        )
                )
                .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(
            // Main header background with apocalyptic gradients
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black,
                            Color.red.opacity(0.1),
                            Color.black,
                            Color.orange.opacity(0.05),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                        .opacity(pulseAnimation ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                )
        )
        .shadow(color: .red.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}