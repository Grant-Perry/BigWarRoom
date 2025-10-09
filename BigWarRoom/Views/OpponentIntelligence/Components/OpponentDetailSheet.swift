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
            
            Text(intelligence.opponentTeam.ownerName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            // Score comparison
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
                    Text(intelligence.threatLevel.emoji)
                        .font(.system(size: 20))
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
            
            LazyVStack(spacing: 8) {
                ForEach(intelligence.players.sorted { $0.currentScore > $1.currentScore }) { player in
                    OpponentPlayerCard(player: player)
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