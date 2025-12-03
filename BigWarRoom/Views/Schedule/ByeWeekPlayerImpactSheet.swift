//
//  ByeWeekPlayerImpactSheet.swift
//  BigWarRoom
//
//  Sheet displaying which fantasy players are affected by a bye week
//  Shows leagues and specific players currently rostered
//

import SwiftUI

struct ByeWeekPlayerImpactSheet: View {
    let impact: ByeWeekImpact
    let teamName: String
    let teamCode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header bar (no NavigationStack needed for sheet)
                HStack {
                    Text("Bye Week \(WeekSelectionManager.shared.selectedWeek) Impact")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                        
                        // Affected players grouped by league
                        ForEach(Array(impact.groupedByLeague.keys.sorted()), id: \.self) { leagueName in
                            if let players = impact.groupedByLeague[leagueName] {
                                leagueSection(leagueName: leagueName, players: players)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Team logo instead of warning icon
            TeamAssetManager.shared.logoOrFallback(for: teamCode)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color.gpRedPink.opacity(0.2))
                        .frame(width: 90, height: 90)
                )
            
            // Team name
            Text(teamName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Impact count
            Text("\(impact.affectedPlayerCount) Active Player\(impact.affectedPlayerCount == 1 ? "" : "s") on Bye")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gpRedPink.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpRedPink.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - League Section
    
    private func leagueSection(leagueName: String, players: [AffectedPlayer]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // League name header
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gpOrange)
                
                Text(leagueName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(players.count) player\(players.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Players list
            VStack(spacing: 8) {
                ForEach(players) { player in
                    playerCard(player: player)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Player Card
    
    private func playerCard(player: AffectedPlayer) -> some View {
        HStack(spacing: 12) {
            // Position badge
            Text(player.position)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(positionColor(player.position).opacity(0.3))
                        .overlay(
                            Circle()
                                .stroke(positionColor(player.position), lineWidth: 2)
                        )
                )
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(player.fantasyTeamName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Bye indicator
            VStack(spacing: 2) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
                Text("BYE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    // MARK: - Helper
    
    private func positionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .blue
        case "RB": return .red
        case "WR": return .green
        case "TE": return .orange
        case "K": return .purple
        case "D/ST", "DEF": return .gray
        default: return .white
        }
    }
}

#Preview("Bye Week Impact Sheet") {
    let sampleImpact = ByeWeekImpact(
        teamCode: "KC",
        affectedPlayers: [
            AffectedPlayer(
                playerName: "Patrick Mahomes",
                position: "QB",
                nflTeam: "KC",
                leagueName: "The Big League",
                fantasyTeamName: "Team Awesome",
                currentPoints: 0,
                projectedPoints: 24.5,
                sleeperID: "4046"
            ),
            AffectedPlayer(
                playerName: "Travis Kelce",
                position: "TE",
                nflTeam: "KC",
                leagueName: "The Big League",
                fantasyTeamName: "Team Awesome",
                currentPoints: 0,
                projectedPoints: 15.2,
                sleeperID: "4137"
            ),
            AffectedPlayer(
                playerName: "Isiah Pacheco",
                position: "RB",
                nflTeam: "KC",
                leagueName: "Another League",
                fantasyTeamName: "Champions",
                currentPoints: 0,
                projectedPoints: 12.8,
                sleeperID: "8138"
            )
        ]
    )
    
    ByeWeekPlayerImpactSheet(
        impact: sampleImpact,
        teamName: "Kansas City Chiefs",
        teamCode: "KC"
    )
    .preferredColorScheme(.dark)
}