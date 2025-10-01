//
//  CompactTeamRosterPlayerCard.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Updated to use shared player card components
//  Uses PlayerCardComponents for consistent styling and reduced duplication
//

import SwiftUI

/// Enhanced Compact Team Roster Player Card - Now using shared components
struct CompactTeamRosterPlayerCard: View {
    let pick: EnhancedPick
    let onPlayerTap: (SleeperPlayer) -> Void
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Top row: Pick # + Team Logo + Position (using shared components)
            HStack(spacing: 8) {
                // 🔥 REFACTOR: Using UnifiedPickNumberDisplay
                UnifiedPickNumberDisplay(
                    configuration: .compact(
                        round: pick.round,
                        pick: pick.pickInRound,
                        order: pickOrder
                    )
                )
                
                Spacer()
                
                // Team logo (smaller)
                TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                    .frame(width: 14, height: 14)
                
                // 🔥 REFACTOR: Using UnifiedPositionBadge
                if let realPlayer = findRealSleeperPlayer(),
                   let positionRank = realPlayer.positionalRank {
                    UnifiedPositionBadge(
                        configuration: .positionalRank(
                            position: pick.position,
                            rank: positionRank,
                            size: .small
                        )
                    )
                } else if let positionRank = pick.player.positionalRank {
                    UnifiedPositionBadge(
                        configuration: .positionalRank(
                            position: pick.position,
                            rank: positionRank,
                            size: .small
                        )
                    )
                } else {
                    UnifiedPositionBadge(
                        configuration: .small(position: pick.position)
                    )
                }
            }
            
            // Second row: Player image + Player name
            HStack(spacing: 12) {
                // 🔥 REFACTOR: Using UnifiedPlayerImageView with position border
                ZStack {
                    Circle()
                        .fill(PlayerCardPositionColorSystem.color(for: pick.position, opacity: 0.3))
                        .frame(width: 52, height: 52)
                        .blur(radius: 2)
                    
                    UnifiedPlayerImageView(
                        configuration: .enhancedPick(
                            pick: pick,
                            size: 48,
                            borderStyle: .position(pick.position)
                        )
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
        // 🔥 REFACTOR: Using PlayerCardGradientSystem
        .background(PlayerCardGradientSystem.positionGradient(for: pick.position))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PlayerCardPositionColorSystem.color(for: pick.position, opacity: 0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            if let realSleeperPlayer = findRealSleeperPlayer() {
                onPlayerTap(realSleeperPlayer)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Pick order calculation
    private var pickOrder: Int {
        let allTeamPicks = viewModel.allDraftPicks
            .filter { $0.draftSlot == pick.draftSlot }
            .sorted { $0.pickNumber < $1.pickNumber }
        
        return (allTeamPicks.firstIndex { $0.pickNumber == pick.pickNumber } ?? 0) + 1
    }
    
    // MARK: - Enhanced Sleeper Player Lookup
    
    private func findRealSleeperPlayer() -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        // Direct match first
        if let directMatch = PlayerDirectoryStore.shared.players[pick.player.playerID] {
            return directMatch
        }
        
        // Exact match
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
            
            // Fuzzy match
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
}