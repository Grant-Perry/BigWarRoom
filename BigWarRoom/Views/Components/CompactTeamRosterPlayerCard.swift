//
//  CompactTeamRosterPlayerCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Enhanced Compact Team Roster Player Card
struct CompactTeamRosterPlayerCard: View {
    let pick: EnhancedPick
    let onPlayerTap: (SleeperPlayer) -> Void
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Top row: Pick # + Team Logo + Position (all smaller)
            HStack(spacing: 8) {
                // Smaller pick number
                Text(roundPickOrderFormat)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 16)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gpBlue)
                    )
                
                Spacer()
                
                // Team logo (smaller)
                TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                    .frame(width: 14, height: 14)
                
                // Position badge (smaller)
                if let realPlayer = findRealSleeperPlayer(),
                   let positionRank = realPlayer.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(positionColor(pick.position))
                        )
                } else if let positionRank = pick.player.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(positionColor(pick.position))
                        )
                } else {
                    Text(pick.position)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(positionColor(pick.position))
                        )
                }
            }
            
            // Second row: Larger player image + Player name taking full width
            HStack(spacing: 12) {
                // Larger player image
                ZStack {
                    Circle()
                        .fill(positionColor(pick.position).opacity(0.3))
                        .frame(width: 52, height: 52)
                        .blur(radius: 2)
                    
                    playerImageForPick()
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(positionColor(pick.position).opacity(0.6), lineWidth: 2)
                        )
                }
                
                // Player name taking full width
                HStack {
                    Text(pick.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    // Fantasy rank (if available)
                    if let realPlayer = findRealSleeperPlayer(),
                       let searchRank = realPlayer.searchRank {
                        Text("#\(searchRank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpYellow)
                    } else if let searchRank = pick.player.searchRank {
                        Text("#\(searchRank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpYellow)
                    }
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(0.7), location: 0.0),
                    .init(color: positionColor(pick.position).opacity(0.2), location: 0.5),
                    .init(color: Color.black.opacity(0.8), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(positionColor(pick.position).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            if let realSleeperPlayer = findRealSleeperPlayer() {
                onPlayerTap(realSleeperPlayer)
            }
        }
    }
    
    // MARK: - Round.Pick.Order Format Helper
    
    private var roundPickOrderFormat: String {
        let actualRound = pick.round
        let actualPickInRound = pick.pickInRound
        
        let allTeamPicks = viewModel.allDraftPicks
            .filter { $0.draftSlot == pick.draftSlot }
            .sorted { $0.pickNumber < $1.pickNumber }
        
        let pickOrder = (allTeamPicks.firstIndex { $0.pickNumber == pick.pickNumber } ?? 0) + 1
        
        return "\(actualRound).\(actualPickInRound).\(pickOrder)"
    }
    
    // MARK: - Enhanced Player Image with Real Sleeper Lookup
    
    @ViewBuilder
    private func playerImageForPick() -> some View {
        if let realSleeperPlayer = findRealSleeperPlayer() {
            PlayerImageView(
                player: realSleeperPlayer,
                size: 48,
                team: pick.team
            )
        } else {
            PlayerImageView(
                player: pick.player,
                size: 48,
                team: pick.team
            )
        }
    }
    
    // MARK: - Enhanced Sleeper Player Lookup
    
    private func findRealSleeperPlayer() -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        if let directMatch = PlayerDirectoryStore.shared.players[pick.player.playerID] {
            return directMatch
        }
        
        if let firstName = pick.player.firstName,
           let lastName = pick.player.lastName,
           let team = pick.player.team,
           let position = pick.player.position {
            
            let exactMatch = allSleeperPlayers.first { sleeperPlayer in
                let firstNameMatches = sleeperPlayer.firstName?.lowercased() == firstName.lowercased()
                let lastNameMatches = sleeperPlayer.lastName?.lowercased() == lastName.lowercased()
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                let positionMatches = sleeperPlayer.position?.uppercased() == position.uppercased()
                
                return firstNameMatches && lastNameMatches && teamMatches && positionMatches
            }
            
            if let exactMatch = exactMatch {
                return exactMatch
            }
            
            let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
                guard let sleeperFirst = sleeperPlayer.firstName,
                      let sleeperLast = sleeperPlayer.lastName else { return false }
                
                let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == firstName.prefix(1).uppercased()
                let lastNameContains = sleeperLast.lowercased().contains(lastName.lowercased()) || 
                                       lastName.lowercased().contains(sleeperLast.lowercased())
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                
                return firstInitialMatches && lastNameContains && teamMatches
            }
            
            return fuzzyMatch
        }
        
        return nil
    }
    
    // Enhanced position colors
    private func positionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return Color(red: 0.6, green: 0.3, blue: 0.9) // Purple
        case "RB": return Color(red: 0.2, green: 0.8, blue: 0.4) // Green
        case "WR": return Color(red: 0.3, green: 0.6, blue: 1.0) // Blue
        case "TE": return Color(red: 1.0, green: 0.6, blue: 0.2) // Orange
        case "K": return Color(red: 0.7, green: 0.7, blue: 0.7) // Gray
        case "DEF", "DST": return Color(red: 0.9, green: 0.3, blue: 0.3) // Red
        default: return Color(red: 0.6, green: 0.6, blue: 0.6) // Default Gray
        }
    }
}