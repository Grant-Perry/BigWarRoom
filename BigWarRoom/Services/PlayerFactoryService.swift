//
//  PlayerFactoryService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Centralized FantasyPlayer creation from various sources
//  Eliminates duplicate player construction logic across 5+ files
//

import Foundation

/// Centralized service for creating FantasyPlayer objects from various data sources
/// Ensures consistent player creation and eliminates duplicate logic
@MainActor
final class PlayerFactoryService {
    
    // MARK: - Singleton
    static let shared: PlayerFactoryService = {
        let service = PlayerFactoryService(
            playerDirectory: .shared,
            gameStatusService: .shared
        )
        return service
    }()
    
    // MARK: - Dependencies
    private let playerDirectory: PlayerDirectoryStore
    private let gameStatusService: GameStatusService
    
    // MARK: - Initialization
    
    init(
        playerDirectory: PlayerDirectoryStore,
        gameStatusService: GameStatusService
    ) {
        self.playerDirectory = playerDirectory
        self.gameStatusService = gameStatusService
    }
    
    // MARK: - Factory Methods
    
    /// Create FantasyPlayer from Sleeper player ID with optional override values
    func createPlayer(
        sleeperID: String,
        currentPoints: Double? = nil,
        projectedPoints: Double? = nil,
        isStarter: Bool = false,
        lineupSlot: String? = nil
    ) -> FantasyPlayer? {
        guard let sleeperPlayer = playerDirectory.player(for: sleeperID) else {
            return nil
        }
        
        return FantasyPlayer(
            id: sleeperID,
            sleeperID: sleeperID,
            espnID: sleeperPlayer.espnID,
            firstName: sleeperPlayer.firstName,
            lastName: sleeperPlayer.lastName,
            position: sleeperPlayer.position ?? "FLEX",
            team: sleeperPlayer.team,
            jerseyNumber: sleeperPlayer.number?.description,
            currentPoints: currentPoints,
            projectedPoints: projectedPoints,
            gameStatus: gameStatusService.getGameStatusWithFallback(for: sleeperPlayer.team),
            isStarter: isStarter,
            lineupSlot: lineupSlot ?? sleeperPlayer.position,
            injuryStatus: sleeperPlayer.injuryStatus
        )
    }
    
    /// Create FantasyPlayer from PlayerSnapshot (MatchupDataStore)
    func createPlayer(from snapshot: PlayerSnapshot) -> FantasyPlayer {
        // Convert game status string to GameStatus struct (if present)
        let gameStatus: GameStatus? = snapshot.metrics.gameStatus.map { statusString in
            GameStatus(status: statusString)
        }
        
        return FantasyPlayer(
            id: snapshot.id,
            sleeperID: snapshot.identity.sleeperID,
            espnID: snapshot.identity.espnID,
            firstName: snapshot.identity.firstName,
            lastName: snapshot.identity.lastName,
            position: snapshot.context.position,
            team: snapshot.context.team,
            jerseyNumber: snapshot.context.jerseyNumber,
            currentPoints: snapshot.metrics.currentScore,
            projectedPoints: snapshot.metrics.projectedScore,
            gameStatus: gameStatus,
            isStarter: snapshot.context.isStarter,
            lineupSlot: snapshot.context.lineupSlot,
            injuryStatus: snapshot.context.injuryStatus
        )
    }
    
    /// Create FantasyPlayer from Sleeper matchup response player
    func createPlayer(
        sleeperID: String,
        sleeperMatchup: SleeperMatchupResponse?,
        isStarter: Bool,
        calculatedPoints: Double? = nil,
        calculatedProjection: Double? = nil
    ) -> FantasyPlayer? {
        guard let sleeperPlayer = playerDirectory.player(for: sleeperID) else {
            return nil
        }
        
        // Use calculated points if provided, otherwise try to extract from matchup
        let currentPoints = calculatedPoints
        let projectedPoints = calculatedProjection
        
        return FantasyPlayer(
            id: sleeperID,
            sleeperID: sleeperID,
            espnID: sleeperPlayer.espnID,
            firstName: sleeperPlayer.firstName,
            lastName: sleeperPlayer.lastName,
            position: sleeperPlayer.position ?? "FLEX",
            team: sleeperPlayer.team,
            jerseyNumber: sleeperPlayer.number?.description,
            currentPoints: currentPoints,
            projectedPoints: projectedPoints,
            gameStatus: gameStatusService.getGameStatusWithFallback(for: sleeperPlayer.team),
            isStarter: isStarter,
            lineupSlot: sleeperPlayer.position,
            injuryStatus: sleeperPlayer.injuryStatus
        )
    }
    
    /// Create a placeholder "Eliminated" player for playoff elimination displays
    func createEliminatedPlaceholder() -> FantasyPlayer {
        return FantasyPlayer(
            id: "eliminated_placeholder",
            sleeperID: nil,
            espnID: nil,
            firstName: "Eliminated",
            lastName: "Team",
            position: "FLEX",
            team: nil,
            jerseyNumber: nil,
            currentPoints: 0.0,
            projectedPoints: 0.0,
            gameStatus: nil,
            isStarter: false,
            lineupSlot: nil,
            injuryStatus: nil
        )
    }
    
    // MARK: - Bulk Creation
    
    /// Create multiple players from Sleeper IDs
    func createPlayers(
        sleeperIDs: [String],
        starterIDs: Set<String> = [],
        pointsMap: [String: Double] = [:],
        projectionsMap: [String: Double] = [:]
    ) -> [FantasyPlayer] {
        return sleeperIDs.compactMap { playerID in
            createPlayer(
                sleeperID: playerID,
                currentPoints: pointsMap[playerID],
                projectedPoints: projectionsMap[playerID],
                isStarter: starterIDs.contains(playerID)
            )
        }
    }
    
    // MARK: - ESPN Support (TODO: Uncomment when ESPN models are refactored)
    
    /*
    /// Create FantasyPlayer from ESPN roster entry
    func createPlayer(
        espnRosterEntry: ESPNFantasyRosterEntry,
        espnPlayerInfo: ESPNFantasyPlayerModel?,
        currentPoints: Double? = nil,
        projectedPoints: Double? = nil,
        isStarter: Bool = false
    ) -> FantasyPlayer? {
        // ESPN player creation logic - temporarily disabled
        return nil
    }
    */
    
    // MARK: - Helper Methods
    
    /// Convert ESPN position slot ID to position string
    private func convertESPNPosition(_ slotID: Int) -> String? {
        switch slotID {
        case 0: return "QB"
        case 2: return "RB"
        case 4: return "WR"
        case 6: return "TE"
        case 16: return "DEF"
        case 17: return "K"
        case 20: return "BENCH"
        case 21: return "IR"
        case 23: return "FLEX"
        default: return nil
        }
    }
    
    /// Convert ESPN team ID to NFL team code
    private func convertESPNTeamID(_ teamID: Int) -> String? {
        // ESPN team IDs (simplified mapping)
        let teamMap: [Int: String] = [
            1: "ATL", 2: "BUF", 3: "CHI", 4: "CIN", 5: "CLE",
            6: "DAL", 7: "DEN", 8: "DET", 9: "GB", 10: "TEN",
            11: "IND", 12: "KC", 13: "LV", 14: "LAR", 15: "MIA",
            16: "MIN", 17: "NE", 18: "NO", 19: "NYG", 20: "NYJ",
            21: "PHI", 22: "ARI", 23: "PIT", 24: "LAC", 25: "SF",
            26: "SEA", 27: "TB", 28: "WAS", 29: "CAR", 30: "JAX",
            33: "BAL", 34: "HOU"
        ]
        return teamMap[teamID]
    }
}