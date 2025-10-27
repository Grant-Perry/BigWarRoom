//
//  FantasyMatchupCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Fantasy Matchup Card component
struct FantasyMatchupCard: View {
    let matchup: FantasyMatchup
    @State var fantasyViewModel: FantasyViewModel = FantasyViewModel.shared  // 🔥 PHASE 3: Use @State for @Observable
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with week info
            HStack {
                Text("Week \(matchup.week)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(matchup.winProbabilityString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Main matchup content
            HStack(spacing: 0) {
                // Away team (left side)
                MatchupTeamSectionView(
                    team: matchup.awayTeam,
                    score: matchup.awayTeam.currentScoreString,
                    isHome: false,
                    fantasyViewModel: fantasyViewModel  // 🔥 NEW: Pass FantasyViewModel
                )
                
                // VS divider  
                VStack {
                    Text("VS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Week \(matchup.week)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(matchup.winProbabilityString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
                .frame(width: 60)
                
                // Home team (right side)
                MatchupTeamSectionView(
                    team: matchup.homeTeam,
                    score: matchup.homeTeam.currentScoreString,
                    isHome: true,
                    fantasyViewModel: fantasyViewModel  // 🔥 NEW: Pass FantasyViewModel
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Team section within a matchup card
struct MatchupTeamSectionView: View {
    let team: FantasyTeam
    let score: String
    let isHome: Bool
    let fantasyViewModel: FantasyViewModel  // 🔥 NEW: Access to FantasyViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Team avatar - Enhanced for ESPN teams
            TeamAvatarView(team: team)
            
            // Team info
            VStack(spacing: 2) {
                Text(team.ownerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // 🔥 NEW: Only show record if not empty (Sleeper only)
                let teamRecord = fantasyViewModel.getManagerRecord(managerID: team.id)
                if !teamRecord.isEmpty {
                    Text(teamRecord)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            // Score
            Text(score)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isHome ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
}