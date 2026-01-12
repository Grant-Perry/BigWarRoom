//
//  DataConversionService.swift
//  BigWarRoom
//
//  Service to consolidate all data conversion/parsing logic (DRY)
//  Eliminates ~300+ lines of duplicate conversion code across ViewModels and Services
//

import Foundation

/// Service responsible for converting between data types
/// Consolidates: parseRecord, parseMatchupStatus, buildFantasyPlayer, convertTeamSnapshot, etc.
@MainActor
final class DataConversionService {
    
    // MARK: - Singleton (stateless utility service)
    static let shared = DataConversionService()
    
    private init() {}
    
    // MARK: - Record Parsing
    
    /// Parse record string (e.g. "10-4" or "10-4-1") into TeamRecord
    /// Consolidates duplicate logic from MatchupsHubViewModel+Loading, FantasyViewModel+Refresh
    func parseRecord(_ recordString: String) -> TeamRecord? {
        guard !recordString.isEmpty else { return nil }
        let parts = recordString.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        
        let wins = Int(parts[0]) ?? 0
        let losses = Int(parts[1]) ?? 0
        let ties = parts.count > 2 ? Int(parts[2]) : nil
        
        return TeamRecord(wins: wins, losses: losses, ties: ties)
    }
    
    /// Format TeamRecord into string (e.g. "10-4" or "10-4-1")
    /// Consolidates duplicate logic from MatchupDataStore
    func formatRecord(_ record: TeamRecord?) -> String {
        guard let record = record else { return "" }
        return FormattingService.formatRecord(record)
    }
    
    // MARK: - Matchup Status Parsing
    
    /// Parse matchup status string to enum
    /// Consolidates duplicate logic from MatchupsHubViewModel+Loading, FantasyViewModel+Refresh
    func parseMatchupStatus(_ statusString: String) -> MatchupStatus {
        switch statusString.lowercased() {
        case "live", "in_progress":
            return .live
        case "completed", "final", "complete":
            return .complete
        default:
            return .upcoming
        }
    }
    
    // MARK: - Player Conversion
    
    /// Build FantasyPlayer from PlayerSnapshot
    /// Consolidates conversion logic from MatchupsHubViewModel+Loading
    func buildFantasyPlayer(from snapshot: PlayerSnapshot) -> FantasyPlayer {
        // Convert game status string back to GameStatus struct (if present)
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
            injuryStatus: snapshot.context.injuryStatus,
            lastActivityTime: snapshot.metrics.lastActivity
        )
    }
    
    /// Build PlayerSnapshot from FantasyPlayer
    /// Consolidates conversion logic from MatchupDataStore
    func buildPlayerSnapshot(from player: FantasyPlayer) -> PlayerSnapshot {
        return PlayerSnapshot(
            id: player.id,
            identity: PlayerSnapshot.PlayerIdentity(
                playerID: player.id,
                sleeperID: player.sleeperID,
                espnID: player.espnID,
                firstName: player.firstName ?? "",
                lastName: player.lastName ?? "",
                fullName: player.fullName
            ),
            metrics: PlayerSnapshot.PlayerMetrics(
                currentScore: player.currentPoints ?? 0.0,
                projectedScore: player.projectedPoints ?? 0.0,
                delta: 0.0,  // Calculated during delta updates
                lastActivity: player.lastActivityTime,
                gameStatus: player.gameStatus?.status
            ),
            context: PlayerSnapshot.PlayerContext(
                position: player.position,
                lineupSlot: player.lineupSlot,
                isStarter: player.isStarter,
                team: player.team,
                injuryStatus: player.injuryStatus,
                jerseyNumber: player.jerseyNumber,
                kickoffTime: nil  // TODO: Get from game data when available
            )
        )
    }
    
    // MARK: - Team Conversion
    
    /// Convert TeamSnapshot to FantasyTeam
    /// Consolidates conversion logic from MatchupsHubViewModel+Loading
    func convertTeamSnapshot(_ snapshot: TeamSnapshot) -> FantasyTeam {
        let roster = snapshot.roster.map { player in
            buildFantasyPlayer(from: player)
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
    
    /// Build TeamSnapshot from FantasyTeam
    /// Consolidates conversion logic from MatchupDataStore
    func buildTeamSnapshot(from team: FantasyTeam, winProbability: Double?, margin: Double) -> TeamSnapshot {
        return TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: team.id,
                ownerName: team.ownerName,
                record: formatRecord(team.record),
                avatarURL: team.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: team.currentScore ?? 0.0,
                projected: team.projectedScore ?? 0.0,
                winProbability: winProbability,
                margin: margin
            ),
            roster: team.roster.map { buildPlayerSnapshot(from: $0) }
        )
    }
    
    // MARK: - Matchup Conversion
    
    /// Convert MatchupSnapshot to FantasyMatchup
    /// Consolidates conversion logic from MatchupsHubViewModel+Loading
    func convertSnapshotToFantasyMatchup(_ snapshot: MatchupSnapshot, year: String) -> FantasyMatchup {
        return FantasyMatchup(
            id: snapshot.id.matchupID,
            leagueID: snapshot.id.leagueID,
            week: snapshot.id.week,
            year: year,
            homeTeam: convertTeamSnapshot(snapshot.homeTeam),
            awayTeam: convertTeamSnapshot(snapshot.awayTeam),
            status: parseMatchupStatus(snapshot.metadata.status),
            winProbability: snapshot.myTeam.score.winProbability,
            startTime: snapshot.metadata.startTime,
            sleeperMatchups: nil
        )
    }
}
