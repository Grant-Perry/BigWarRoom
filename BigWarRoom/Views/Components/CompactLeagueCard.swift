//
//  CompactLeagueCard.swift
//  BigWarRoom
//
//  Compact league selection card for sports app style UI
// displays on the Connection -> Selected Draft -> Your Leagues
//

import SwiftUI

struct CompactLeagueCard: View {
    let leagueWrapper: UnifiedLeagueManager.LeagueWrapper
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // League source icon
                Group {
                    if leagueWrapper.source == .sleeper {
                        AppConstants.sleeperLogo
                            .frame(width: 20, height: 20)
                    } else {
                        AppConstants.espnLogo
                            .frame(width: 20, height: 20)
                    }
                }
                
                // League info
                VStack(alignment: .leading, spacing: 2) {
                    Text("  \(leagueWrapper.league.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gpGreen)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("\(leagueWrapper.league.totalRosters) teams")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if leagueWrapper.league.status == .drafting {
                            Text("• DRAFTING")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                Color.green.opacity(0.1) : 
                Color(.systemGray6).opacity(0.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.green : Color.clear, 
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 8) {
        CompactLeagueCard(
            leagueWrapper: UnifiedLeagueManager.LeagueWrapper(
                id: "sleeper_test1",
                league: SleeperLeague(
                    leagueID: "test1",
                    name: "My Fantasy League",
                    status: .drafting,
                    sport: "nfl",
                    season: "2024",
                    seasonType: "regular",
                    totalRosters: 12,
                    draftID: "test_draft",
                    avatar: nil,
                    settings: nil,
                    scoringSettings: nil,
                    rosterPositions: nil
                ),
                source: .sleeper,
                client: SleeperAPIClient.shared
            ),
            isSelected: false,
            onSelect: {}
        )
        
        CompactLeagueCard(
            leagueWrapper: UnifiedLeagueManager.LeagueWrapper(
                id: "espn_test2",
                league: SleeperLeague(
                    leagueID: "test2",
                    name: "ESPN Championship",
                    status: .complete,
                    sport: "nfl", 
                    season: "2024",
                    seasonType: "regular",
                    totalRosters: 10,
                    draftID: "espn_draft",
                    avatar: nil,
                    settings: nil,
                    scoringSettings: nil,
                    rosterPositions: nil
                ),
                source: .espn,
                client: ESPNAPIClient.shared
            ),
            isSelected: true,
            onSelect: {}
        )
    }
    .padding()
}
