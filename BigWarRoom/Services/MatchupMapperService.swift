//
//  MatchupMapperService.swift
//  BigWarRoom
//
//  🔥 DRY: Single source of truth for converting between MatchupSnapshot and FantasyMatchup
//  Extracted from FantasyViewModel+Refresh to follow MVVM and SRP
//

import Foundation

/// Service for mapping between MatchupSnapshot (store format) and FantasyMatchup (UI format)
@MainActor
final class MatchupMapperService {
    
    // MARK: - Public Interface
    
    /// Convert MatchupSnapshot to FantasyMatchup for UI display
    func snapshotToFantasyMatchup(
        _ snapshot: MatchupSnapshot,
        year: String
    ) -> FantasyMatchup {
        
        // Convert team snapshots to FantasyTeam
        let homeTeam = teamSnapshotToFantasyTeam(snapshot.myTeam)
        let awayTeam = teamSnapshotToFantasyTeam(snapshot.opponentTeam)
        
        // Parse matchup status
        let status = parseMatchupStatus(snapshot.metadata.status)
        
        return FantasyMatchup(
            id: snapshot.id.matchupID,
            leagueID: snapshot.id.leagueID,
            week: snapshot.id.week,
            year: year,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            status: status,
            winProbability: snapshot.myTeam.score.winProbability,
            startTime: snapshot.metadata.startTime,
            sleeperMatchups: nil
        )
    }
    
    // MARK: - Private Helpers
    
    /// Convert TeamSnapshot to FantasyTeam
    private func teamSnapshotToFantasyTeam(_ snapshot: TeamSnapshot) -> FantasyTeam {
        let roster = snapshot.roster.map { player in
            // Convert game status string back to GameStatus struct (if present)
            let gameStatus: GameStatus? = player.metrics.gameStatus.map { statusString in
                GameStatus(status: statusString)
            }
            
            return FantasyPlayer(
                id: player.id,
                sleeperID: player.identity.sleeperID,
                espnID: player.identity.espnID,
                firstName: player.identity.firstName,
                lastName: player.identity.lastName,
                position: player.context.position,
                team: player.context.team,
                jerseyNumber: player.context.jerseyNumber,
                currentPoints: player.metrics.currentScore,
                projectedPoints: player.metrics.projectedScore,
                gameStatus: gameStatus,
                isStarter: player.context.isStarter,
                lineupSlot: player.context.lineupSlot,
                injuryStatus: player.context.injuryStatus
            )
        }
        
        return FantasyTeam(
            id: snapshot.info.teamID,
            name: snapshot.info.ownerName,
            ownerName: snapshot.info.ownerName,
            record: parseRecord(snapshot.info.record),
            avatar: snapshot.info.avatarURL,
            currentScore: snapshot.score.actual,
            projectedScore: snapshot.score.projected,
            roster: roster,
            rosterID: Int(snapshot.info.teamID) ?? 0,
            faabTotal: nil,
            faabUsed: nil
        )
    }
    
    /// Parse record string into TeamRecord
    private func parseRecord(_ recordString: String) -> TeamRecord? {
        guard !recordString.isEmpty else { return nil }
        let parts = recordString.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        let wins = Int(parts[0]) ?? 0
        let losses = Int(parts[1]) ?? 0
        let ties = parts.count > 2 ? Int(parts[2]) : nil
        return TeamRecord(wins: wins, losses: losses, ties: ties)
    }
    
    /// Parse matchup status string to enum
    private func parseMatchupStatus(_ statusString: String) -> MatchupStatus {
        switch statusString.lowercased() {
        case "live", "in_progress":
            return .live
        case "completed", "final":
            return .complete
        default:
            return .upcoming
        }
    }
}