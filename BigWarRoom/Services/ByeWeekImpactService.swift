//
//  ByeWeekImpactService.swift
//  BigWarRoom
//
//  Service to analyze fantasy roster impact of NFL bye weeks
//  Cross-references user's active lineups against teams on bye
//

import Foundation

@MainActor
final class ByeWeekImpactService {
    static let shared = ByeWeekImpactService()
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Analyze bye week impact for a specific NFL team
    /// Returns all affected players in active lineups across all leagues
    func analyzeByeWeekImpact(
        for teamCode: String,
        week: Int,
        unifiedLeagueManager: UnifiedLeagueManager,
        matchupsHubViewModel: MatchupsHubViewModel
    ) async -> ByeWeekImpact {
        
        var affectedPlayers: [AffectedPlayer] = []
        let normalizedTeamCode = normalizeTeamCode(teamCode)
        
        // Use the already-loaded matchups from MatchupsHubViewModel
        let allMatchups = matchupsHubViewModel.myMatchups
        
        DebugPrint(mode: .weekCheck, "🔍 Analyzing bye impact for \(teamCode) across \(allMatchups.count) matchups")
        
        for matchup in allMatchups {
            // 🔥 SKIP: Eliminated chopped leagues - they don't matter anymore!
            if matchup.isMyManagerEliminated {
                DebugPrint(mode: .weekCheck, "   ⏭️ Skipping \(matchup.league.league.name) - already eliminated")
                continue
            }
            
            // Get my team's starting lineup
            guard let myTeam = matchup.myTeam else { continue }
            
            let leagueName = matchup.league.league.name
            
            // Filter to starting lineup players only
            let starters = myTeam.roster.filter { $0.isStarter }
            
            // Find players on the bye team
            for player in starters {
                guard let playerTeam = player.team, !playerTeam.isEmpty else {
                    continue
                }
                
                if normalizeTeamCode(playerTeam) == normalizedTeamCode {
                    let affectedPlayer = AffectedPlayer(
                        playerName: player.fullName,
                        position: player.position,
                        nflTeam: playerTeam,
                        leagueName: leagueName,
                        fantasyTeamName: myTeam.name,
                        currentPoints: player.currentPoints,
                        projectedPoints: player.projectedPoints,
                        sleeperID: player.sleeperID
                    )
                    
                    affectedPlayers.append(affectedPlayer)
                    
                    DebugPrint(mode: .weekCheck, "   ⚠️ Found affected player: \(player.fullName) in \(leagueName)")
                }
            }
        }
        
        DebugPrint(mode: .weekCheck, "✅ Total affected players for \(teamCode): \(affectedPlayers.count)")
        
        return ByeWeekImpact(
            teamCode: teamCode,
            affectedPlayers: affectedPlayers
        )
    }
    
    // MARK: - Private Helpers
    
    /// Normalize team codes for consistent matching
    private func normalizeTeamCode(_ teamCode: String) -> String {
        let normalized = teamCode.uppercased().trimmingCharacters(in: .whitespaces)
        
        // Handle special cases
        switch normalized {
        case "WAS", "WSH": return "WSH"  // Washington team code variations
        default: return normalized
        }
    }
}