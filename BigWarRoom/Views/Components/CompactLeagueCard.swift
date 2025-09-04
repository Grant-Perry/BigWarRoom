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
                            .frame(width: 24, height: 24)
                    } else {
                        AppConstants.espnLogo
                            .frame(width: 24, height: 24)
                    }
                }
                
                // League info
                VStack(alignment: .leading, spacing: 4) {
                    Text(leagueWrapper.league.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gpGreen)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(leagueWrapper.league.totalRosters) teams")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if leagueWrapper.league.status == .drafting {
                            Text("• DRAFTING")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                } else {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected ? 
                Color.green.opacity(0.15) : 
                Color(.systemGray6).opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.green.opacity(0.6) : Color.clear, 
                        lineWidth: 2
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