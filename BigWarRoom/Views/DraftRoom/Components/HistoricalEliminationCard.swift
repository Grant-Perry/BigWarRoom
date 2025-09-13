//
//  HistoricalEliminationCard.swift
//  BigWarRoom
//
//  💀🪦 HISTORICAL ELIMINATION CARD 🪦💀
//  The Graveyard - Chronicle of the Fallen
//

import SwiftUI

/// **HistoricalEliminationCard**
/// 
/// Memorial card for teams eliminated in previous weeks.
/// Shows elimination details with dramatic reverence for the fallen.
struct HistoricalEliminationCard: View {
    let elimination: EliminationEvent
    
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingDetails.toggle()
            }
        }) {
            VStack(spacing: 12) {
                // Main elimination info
                HStack(spacing: 12) {
                    // Elimination week badge
                    VStack(spacing: 2) {
                        Text("WEEK")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(elimination.week)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
                            )
                    )
                    
                    // Eliminated team info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("💀")
                                .font(.system(size: 14))
                            
                            Text(elimination.eliminatedTeam.team.ownerName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(String(format: "%.1f pts", elimination.eliminationScore))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }
                        
                        HStack(spacing: 8) {
                            Text("ELIMINATED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.red)
                                .tracking(1)
                            
                            if elimination.margin > 0 {
                                Text("Lost by \(String(format: "%.1f", elimination.margin)) pts")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text(elimination.dramaMeterDisplay.uppercased())
                                .font(.system(size: 7, weight: .black))
                                .foregroundColor(dramaMeterColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(dramaMeterColor.opacity(0.2))
                                )
                        }
                    }
                    
                    // Expand/collapse indicator
                    Image(systemName: showingDetails ? "chevron.up.circle.fill" : "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                
                // Expanded details section
                if showingDetails {
                    VStack(spacing: 8) {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("⚰️ FINAL MOMENTS:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                                
                                Spacer()
                            }
                            
                            if let lastWords = elimination.lastWords {
                                Text("\" \(lastWords) \"")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                                    .italic()
                                    .padding(.leading, 8)
                            }
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("WEEKS SURVIVED")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.gray)
                                    
                                    Text("\(elimination.week - 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ELIMINATION DATE")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.gray)
                                    
                                    Text(eliminationDateString)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.7),
                                Color.gray.opacity(0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(showingDetails ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dramaMeterColor: Color {
        switch elimination.dramaMeter {
        case 0.8...1.0: return .red
        case 0.6..<0.8: return .orange
        case 0.4..<0.6: return .yellow
        case 0.2..<0.4: return .blue
        default: return .gray
        }
    }
    
    private var eliminationDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: elimination.timestamp)
    }
}

// MARK: -> Preview
#Preview {
    let mockTeam = FantasyTeam(
        id: "1",
        name: "Team Eliminated",
        ownerName: "Gp0",
        record: TeamRecord(wins: 5, losses: 8, ties: 0),
        avatar: nil,
        currentScore: 87.4,
        projectedScore: 95.2,
        roster: [],
        rosterID: 1
    )
    
    let mockRanking = FantasyTeamRanking(
        id: "1",
        team: mockTeam,
        weeklyPoints: 87.4,
        rank: 12,
        eliminationStatus: .eliminated,
        isEliminated: true,
        survivalProbability: 0.0,
        pointsFromSafety: -15.2,
        weeksAlive: 8
    )
    
    let mockElimination = EliminationEvent(
        id: "test_elimination",
        week: 9,
        eliminatedTeam: mockRanking,
        eliminationScore: 87.4,
        margin: 3.2,
        dramaMeter: 0.85,
        lastWords: "I thought my lineup was solid this week...",
        timestamp: Date()
    )
    
    VStack {
        HistoricalEliminationCard(elimination: mockElimination)
    }
    .padding()
    .background(Color.black)
}