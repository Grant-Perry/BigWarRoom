//
//  OpponentDetailSheet.swift
//  BigWarRoom
//
//  Detailed sheet view for opponent analysis
//

import SwiftUI

/// Detailed view of a specific opponent's analysis
struct OpponentDetailSheet: View {
    let intelligence: OpponentIntelligence
    @Environment(\.dismiss) private var dismiss
    // 🔥 PURE DI: Inject from environment
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @Environment(NFLWeekService.self) private var nflWeekService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header section
                    headerSection
                    
                    // Threat assessment
                    threatAssessmentSection
                    
                    // Opponent players
                    playersSection
                    
                    // Strategic insights
                    if !intelligence.strategicNotes.isEmpty {
                        strategicNotesSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 50)
            }
            .navigationTitle("Opponent Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // League and opponent name
            HStack {
                Text(intelligence.leagueName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // League source logo - REPLACED text with actual logo
                Group {
                    if intelligence.leagueSource == .espn {
                        Image("espnLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image("sleeperLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
            
            // 🔥 HANDLE CHOPPED LEAGUES: Different header for chopped vs regular leagues
            if let opponentTeam = intelligence.opponentTeam {
                Text(opponentTeam.ownerName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                // Score comparison for regular matchups
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(intelligence.myTeam.currentScoreString)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(intelligence.isLosingTo ? .red : .green)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("vs")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        let diff = intelligence.scoreDifferential
                        Text(diff >= 0 ? "+\(diff.formatted(.number.precision(.fractionLength(1))))" : "\(diff.formatted(.number.precision(.fractionLength(1))))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(diff >= 0 ? .green : .red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Opponent")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(intelligence.totalOpponentScore.formatted(.number.precision(.fractionLength(2))))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(intelligence.isLosingTo ? .green : .red)
                    }
                }
            } else {
                // Chopped league header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("ELIMINATION THREAT")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                }
                
                // Show my score and ranking info for chopped leagues
                if let ranking = intelligence.matchup.myTeamRanking {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Score")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(intelligence.myTeam.currentScoreString)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Current Rank")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(ranking.rankDisplay)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(ranking.eliminationStatus.color)
                            }
                        }
                        
                        // Delta information
                        HStack {
                            Text("Points from Safety:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(ranking.safetyMarginDisplay)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(ranking.pointsFromSafety >= 0 ? .green : .red)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var threatAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Threat Assessment")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack {
                    Image(systemName: intelligence.threatLevel.sfSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(intelligence.threatLevel.color)
                    Text(intelligence.threatLevel.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(intelligence.threatLevel.color)
                }
            }
            
            Text(intelligence.threatLevel.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(intelligence.threatLevel.color.opacity(0.1))
                )
        }
    }
    
    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Opponent Players")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            // 🔥 HANDLE CHOPPED LEAGUES: Show different content if no opponent players
            if intelligence.players.isEmpty {
                // Chopped league - no opponent players to show
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No Opponent Players")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("This is a chopped league elimination threat - you're competing against the entire field.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(intelligence.players.sorted { $0.currentScore > $1.currentScore }) { player in
                        // 🔥 PURE DI: Pass injected instance
                        OpponentPlayerCard(
                            player: player,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                }
            }
        }
    }
    
    private var strategicNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strategic Notes")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            ForEach(Array(intelligence.strategicNotes.enumerated()), id: \.offset) { index, note in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1).")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }
}