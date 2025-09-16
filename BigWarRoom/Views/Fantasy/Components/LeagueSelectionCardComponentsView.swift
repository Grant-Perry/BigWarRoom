//
//  LeagueSelectionCardComponentsView.swift
//  BigWarRoom
//
//  Components for LeagueSelectionCard
//

import SwiftUI

/// League type badge component
struct LeagueSelectionCardTypeBadgeView: View {
    let matchup: UnifiedMatchup
    
    var body: some View {
        Text(matchup.isChoppedLeague ? "CHOPPED" : "\(matchup.league.league.totalRosters) Teams")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(matchup.isChoppedLeague ? Color.purple : Color.blue)
            )
    }
}

/// Source icon component
struct LeagueSelectionCardSourceIconView: View {
    let matchup: UnifiedMatchup
    
    var body: some View {
        HStack(spacing: 4) {
            // Use AppConstants logos at 15x15 size
            if matchup.league.source == .espn {
                AppConstants.espnLogo
                    .frame(width: 15, height: 15)
            } else {
                AppConstants.sleeperLogo  
                    .frame(width: 15, height: 15)
            }
            
            Text(matchup.league.source.rawValue.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

/// My team section component
struct LeagueSelectionCardMyTeamView: View {
    let team: FantasyTeam
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Your Team")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                Spacer()
                Text(String(format: "%.1f pts", team.currentScore ?? 0))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            HStack {
                Text(team.ownerName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                if let record = team.record {
                    Text("\(record.wins)-\(record.losses)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
        }
    }
}

/// Matchup preview component
struct LeagueSelectionCardMatchupPreviewView: View {
    let matchup: UnifiedMatchup
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            if matchup.isChoppedLeague {
                // Chopped league preview
                HStack {
                    Text("Rank")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    Spacer()
                    
                    if let ranking = matchup.myTeamRanking {
                        Text("#\(ranking.rank)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isSelected ? .white : .gpGreen)
                    }
                }
            } else {
                // Standard matchup preview
                if let opponent = matchup.opponentTeam {
                    HStack {
                        Text("vs \(opponent.ownerName)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", opponent.currentScore ?? 0))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
        }
    }
}