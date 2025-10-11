//
//  OpponentIntelligenceService.swift
//  BigWarRoom
//
//  Core service for processing opponent intelligence and conflict detection
//

import Foundation
import SwiftUI

/// **OpponentIntelligenceService**
/// 
/// Analyzes opponents across all leagues and detects strategic conflicts
@MainActor
final class OpponentIntelligenceService {
    static let shared = OpponentIntelligenceService()
    
    // MARK: - Private Properties
    
    private var cachedIntelligence: [OpponentIntelligence] = []
    private var cacheTimestamp: Date?
    private let cacheExpiration: TimeInterval = 30.0 // 30 seconds
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Analyze all opponents from current matchups
    /// - Parameter matchups: Array of unified matchups
    /// - Returns: Array of opponent intelligence analysis
    func analyzeOpponents(from matchups: [UnifiedMatchup]) -> [OpponentIntelligence] {
        let startTime = Date()
        
        // Check cache first
        if let cached = getCachedIntelligence() {
            print("🎯 OpponentIntelligenceService: Returned cached analysis (\(cached.count) opponents)")
            return cached
        }
        
        var intelligence: [OpponentIntelligence] = []
        
        // Extract opponent intelligence from each matchup
        for matchup in matchups {
            if let opponentAnalysis = analyzeOpponentInMatchup(matchup) {
                intelligence.append(opponentAnalysis)
            }
        }
        
        // Detect cross-league conflicts
        let allConflicts = detectCrossLeagueConflicts(from: intelligence, matchups: matchups)
        
        // Update intelligence with conflict data
        intelligence = intelligence.map { intel in
            let matchingConflicts = allConflicts.filter { conflict in
                conflict.opponentLeagues.contains { $0.name == intel.leagueName }
            }
            
            return OpponentIntelligence(
                id: intel.id,
                opponentTeam: intel.opponentTeam,
                myTeam: intel.myTeam,
                leagueName: intel.leagueName,
                leagueSource: intel.leagueSource,
                matchup: intel.matchup,
                players: intel.players,
                conflictPlayers: matchingConflicts,
                threatLevel: intel.threatLevel,
                strategicNotes: intel.strategicNotes
            )
        }
        
        // Cache results
        cachedIntelligence = intelligence
        cacheTimestamp = Date()
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("🎯 OpponentIntelligenceService: Analyzed \(intelligence.count) opponents in \(Int(elapsed * 1000))ms")
        
        return intelligence
    }
    
    /// Generate strategic recommendations based on opponent analysis
    /// - Parameter intelligence: Array of opponent intelligence
    /// - Returns: Array of strategic recommendations
    func generateRecommendations(from intelligence: [OpponentIntelligence]) -> [StrategicRecommendation] {
        var recommendations: [StrategicRecommendation] = []
        
        // FIRST PRIORITY: Injury status alerts for MY players
        let injuryAlerts = generateInjuryAlerts(from: intelligence)
        recommendations.append(contentsOf: injuryAlerts)
        
        // Critical threat recommendations
        let criticalThreats = intelligence.filter { $0.threatLevel == .critical }
        for threat in criticalThreats {
            // Get week context for accurate "yet to play" calculation
            let currentWeek = threat.matchup.fantasyMatchup?.week ?? WeekSelectionManager.shared.selectedWeek
            
            // Calculate yet-to-play counts for both teams
            let myYetToPlay = threat.myTeam.playersYetToPlay(forWeek: currentWeek)
            let theirYetToPlay = threat.opponentTeam.playersYetToPlay(forWeek: currentWeek)
            
            // Enhanced description with yet-to-play information
            let baseDescription = "You're losing to \(threat.opponentTeam.ownerName) by \(abs(threat.scoreDifferential).formatted(.number.precision(.fractionLength(1)))) points in \(threat.leagueName)"
            let yetToPlayInfo = "You have \(myYetToPlay) to play, they have \(theirYetToPlay) to play"
            
            recommendations.append(StrategicRecommendation(
                type: .threatAssessment,
                title: "Critical Threat Alert",
                description: "\(baseDescription). \(yetToPlayInfo)",
                priority: .critical,
                actionable: true,
                opponentTeam: threat.opponentTeam
            ))
        }
        
        // Conflict warnings - Enhanced with league context instead of useless BENCH advice
        let majorConflicts = intelligence.flatMap { $0.conflictPlayers.filter { $0.severity == .extreme || $0.severity == .high } }
        for conflict in majorConflicts {
            // Build league context instead of generic bench advice
            let opponentLeagueNames = conflict.opponentLeagues.map { $0.name }.joined(separator: ", ")
            let impactDirection = conflict.netImpact > 0 ? "benefits" : "hurts"
            let impactAmount = abs(conflict.netImpact).formatted(.number.precision(.fractionLength(1)))
            
            recommendations.append(StrategicRecommendation(
                type: .conflictWarning,
                title: "Player Conflict Detected",
                description: "\(conflict.player.fullName) conflict in \(opponentLeagueNames). Net impact \(impactDirection) you by \(impactAmount) points across leagues",
                priority: conflict.severity == .extreme ? .critical : .high,
                actionable: true,
                opponentTeam: nil // Conflicts don't have a single opponent
            ))
        }
        
        // Opportunity alerts
        let strugglingOpponents = intelligence.filter { $0.totalOpponentScore < 80 && $0.isLosingTo }
        for opportunity in strugglingOpponents {
            recommendations.append(StrategicRecommendation(
                type: .opportunityAlert,
                title: "🎯 Opportunity Window",
                description: "\(opportunity.opponentTeam.ownerName) is struggling (\(opportunity.totalOpponentScore.formatted(.number.precision(.fractionLength(1)))) pts) - maintain aggressive lineup in \(opportunity.leagueName)",
                priority: .medium,
                actionable: false,
                opponentTeam: opportunity.opponentTeam
            ))
        }
        
        // Sort by priority
        return recommendations.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
    
    // MARK: - Injury Alert Generation
    
    /// Generate injury status alerts for all my rostered players
    /// - Parameter intelligence: Array of opponent intelligence containing my team rosters
    /// - Returns: Array of strategic recommendations for injured players
    private func generateInjuryAlerts(from intelligence: [OpponentIntelligence]) -> [StrategicRecommendation] {
        print("🏥 INJURY SCAN: Using AllLivePlayersViewModel for consistent player data")
        
        // Use the same reliable data source as Live Players tab
        let livePlayersViewModel = AllLivePlayersViewModel.shared
        let allMyPlayers = livePlayersViewModel.allPlayers
        
        print("🏥 Found \(allMyPlayers.count) total players from AllLivePlayersViewModel")
        
        var playerInjuries: [String: InjuryAlert] = [:]
        var totalPlayersScanned = 0
        var totalStartersScanned = 0
        var injuriesFound = 0
        
        // Scan all players from the Live Players data source
        for playerEntry in allMyPlayers {
            totalPlayersScanned += 1
            
            // Log every player we're checking
            let starterStatus = playerEntry.isStarter ? "STARTER" : "BENCH"
            print("🏥 Checking: \(playerEntry.player.fullName) (\(starterStatus)) in \(playerEntry.leagueName)")
            
            if playerEntry.isStarter {
                totalStartersScanned += 1
            }
            
            // Check for injury status REGARDLESS of starter status initially
            let isByeWeek = checkIfPlayerOnBye(player: playerEntry.player)
            let sleeperInjuryStatus = getSleeperInjuryStatus(for: playerEntry.player)
            
            print("🏥 \(playerEntry.player.fullName) - BYE: \(isByeWeek), Injury Status: \(sleeperInjuryStatus ?? "None")")
            
            // Determine injury status type
            guard let injuryStatusType = InjuryStatusType.from(
                injuryStatus: sleeperInjuryStatus,
                isByeWeek: isByeWeek
            ) else {
                continue // No concerning injury status
            }
            
            injuriesFound += 1
            print("🏥 INJURY FOUND: \(playerEntry.player.fullName) - Status: \(injuryStatusType.displayName) in \(playerEntry.leagueName)")
            
            // Create league roster entry
            let leagueRoster = InjuryLeagueRoster(
                leagueName: playerEntry.leagueName,
                leagueSource: LeagueSource(rawValue: playerEntry.leagueSource) ?? .sleeper,
                myTeam: playerEntry.matchup.myTeam!, // We know this exists from Live Players
                matchup: playerEntry.matchup,
                isStarterInThisLeague: playerEntry.isStarter
            )
            
            // Use player name as consistent key to handle multi-league players
            let playerKey = playerEntry.player.fullName.lowercased().replacingOccurrences(of: " ", with: "_")
            
            if var existingAlert = playerInjuries[playerKey] {
                // Player already found in another league - add this league roster
                var updatedLeagueRosters = existingAlert.leagueRosters
                updatedLeagueRosters.append(leagueRoster)
                
                // Update the alert with combined league rosters
                let isStarterAnywhere = updatedLeagueRosters.contains { $0.isStarterInThisLeague }
                let priority = InjuryPriority.determine(status: injuryStatusType, isStarter: isStarterAnywhere)
                
                playerInjuries[playerKey] = InjuryAlert(
                    player: existingAlert.player,
                    injuryStatus: injuryStatusType,
                    leagueRosters: updatedLeagueRosters,
                    isStarter: isStarterAnywhere,
                    priority: priority
                )
                
                print("🏥 Updated \(playerEntry.player.fullName) - now in \(updatedLeagueRosters.count) leagues")
            } else {
                // First time seeing this player
                let priority = InjuryPriority.determine(status: injuryStatusType, isStarter: playerEntry.isStarter)
                
                playerInjuries[playerKey] = InjuryAlert(
                    player: playerEntry.player,
                    injuryStatus: injuryStatusType,
                    leagueRosters: [leagueRoster],
                    isStarter: playerEntry.isStarter,
                    priority: priority
                )
                
                print("🏥 Created new entry for \(playerEntry.player.fullName)")
            }
        }
        
        print("🏥 SCAN COMPLETE: \(totalPlayersScanned) total players, \(totalStartersScanned) starters, \(injuriesFound) injuries found")
        
        // Only create alerts for starters (ignore bench injuries)
        let starterAlerts = playerInjuries.values.filter { $0.isStarter }
        
        print("🏥 FINAL RESULT: \(starterAlerts.count) injury alerts created for starters")
        
        // Sort alerts by priority (BYE → IR → O → Q)
        let sortedAlerts = starterAlerts.sorted { alert1, alert2 in
            if alert1.priority.rawValue != alert2.priority.rawValue {
                return alert1.priority.rawValue < alert2.priority.rawValue
            }
            // Within same priority, sort by injury status priority ranking
            return alert1.injuryStatus.priorityRanking < alert2.injuryStatus.priorityRanking
        }
        
        // Convert to StrategicRecommendation objects
        return sortedAlerts.map { $0.asStrategicRecommendation() }
    }
    
    /// Create injury alert for a specific player if they have injury status
    /// - Parameters:
    ///   - player: Fantasy player to check
    ///   - leagueName: Name of the league
    ///   - leagueSource: Source of the league (ESPN/Sleeper)
    ///   - myTeam: My fantasy team containing this player
    /// - Returns: InjuryAlert if player has concerning injury status, nil otherwise
    private func createInjuryAlert(
        player: FantasyPlayer,
        leagueName: String,
        leagueSource: LeagueSource,
        myTeam: FantasyTeam,
        matchup: UnifiedMatchup
    ) -> InjuryAlert? {
        
        return nil
    }
    
    /// Get injury status from Sleeper player directory
    /// - Parameter player: Fantasy player to lookup
    /// - Returns: Injury status string from Sleeper data, if available
    private func getSleeperInjuryStatus(for player: FantasyPlayer) -> String? {
        var foundStatus: String? = nil
        
        // Try to find Sleeper player data using various ID mappings
        if let sleeperID = player.sleeperID,
           let sleeperPlayer = PlayerDirectoryStore.shared.player(for: sleeperID) {
            foundStatus = sleeperPlayer.injuryStatus
            print("🔍 Found \(player.fullName) injury status via SleeperID: \(foundStatus ?? "None")")
            return foundStatus
        }
        
        // Try ESPN ID mapping to Sleeper
        if let espnID = player.espnID,
           let sleeperPlayer = PlayerDirectoryStore.shared.playerByESPNID(espnID) {
            foundStatus = sleeperPlayer.injuryStatus
            print("🔍 Found \(player.fullName) injury status via ESPN ID: \(foundStatus ?? "None")")
            return foundStatus
        }
        
        // Try name-based lookup as fallback - need to search through all players
        let allPlayers = PlayerDirectoryStore.shared.players
        for (_, sleeperPlayer) in allPlayers {
            if sleeperPlayer.fullName.lowercased() == player.fullName.lowercased() {
                foundStatus = sleeperPlayer.injuryStatus
                print("🔍 Found \(player.fullName) injury status via name lookup: \(foundStatus ?? "None")")
                return foundStatus
            }
        }
        
        print("🔍 No injury status found for \(player.fullName) - SleeperID: \(player.sleeperID ?? "None"), ESPN ID: \(player.espnID ?? "None")")
        return nil
    }
    
    /// Check if player is on BYE week using game status service
    /// - Parameter player: Fantasy player to check
    /// - Returns: True if player's team is on BYE this week
    private func checkIfPlayerOnBye(player: FantasyPlayer) -> Bool {
        guard let team = player.team else { 
            print("🏈 \(player.fullName) - No team info available for BYE check")
            return false 
        }
        
        // Use NFLGameDataService to check if team is on bye
        if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
            let isBye = gameInfo.gameStatus.lowercased() == "bye"
            print("🏈 \(player.fullName) (\(team)) - Game status: \(gameInfo.gameStatus), BYE: \(isBye)")
            return isBye
        }
        
        // Fallback: Check if player has 0 projected points (common BYE indicator)
        if let projectedPoints = player.projectedPoints, projectedPoints == 0.0,
           let currentPoints = player.currentPoints, currentPoints == 0.0 {
            print("🏈 \(player.fullName) (\(team)) - BYE detected via 0 points (Projected: \(projectedPoints), Current: \(currentPoints))")
            return true
        }
        
        print("🏈 \(player.fullName) (\(team)) - Not on BYE")
        return false
    }
    
    // MARK: - Private Analysis Methods
    
    private func getCachedIntelligence() -> [OpponentIntelligence]? {
        guard let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheExpiration,
              !cachedIntelligence.isEmpty else {
            return nil
        }
        return cachedIntelligence
    }
    
    private func analyzeOpponentInMatchup(_ matchup: UnifiedMatchup) -> OpponentIntelligence? {
        // Skip chopped leagues for now - they don't have direct opponents
        guard !matchup.isChoppedLeague,
              let opponentTeam = matchup.opponentTeam,
              let myTeam = matchup.myTeam else {
            return nil
        }
        
        // Analyze opponent players
        let opponentPlayers = analyzeOpponentPlayers(opponentTeam.roster, opponentTotalScore: opponentTeam.currentScore ?? 0.0)
        
        // Calculate overall threat level
        let threatLevel = calculateThreatLevel(
            myScore: myTeam.currentScore ?? 0.0,
            opponentScore: opponentTeam.currentScore ?? 0.0,
            opponentProjected: opponentTeam.projectedScore ?? 0.0,
            topPlayerScore: opponentPlayers.map { $0.currentScore }.max() ?? 0.0
        )
        
        // Generate strategic notes
        let strategicNotes = generateStrategicNotes(for: matchup, opponentPlayers: opponentPlayers)
        
        return OpponentIntelligence(
            id: "\(matchup.id)_opponent",
            opponentTeam: opponentTeam,
            myTeam: myTeam,
            leagueName: matchup.league.league.name,
            leagueSource: matchup.league.source,
            matchup: matchup,
            players: opponentPlayers,
            conflictPlayers: [], // Will be populated later
            threatLevel: threatLevel,
            strategicNotes: strategicNotes
        )
    }
    
    private func analyzeOpponentPlayers(_ roster: [FantasyPlayer], opponentTotalScore: Double) -> [OpponentPlayer] {
        return roster.compactMap { player in
            guard player.isStarter else { return nil } // Only analyze starters
            
            let currentScore = player.currentPoints ?? 0.0
            let projectedScore = player.projectedPoints ?? 0.0
            let percentageOfTotal = opponentTotalScore > 0 ? (currentScore / opponentTotalScore) : 0.0
            
            let playerThreat = calculatePlayerThreatLevel(
                currentScore: currentScore,
                projectedScore: projectedScore,
                position: player.position
            )
            
            let matchupAdvantage = assessMatchupAdvantage(for: player)
            
            return OpponentPlayer(
                id: "opponent_\(player.id)",
                player: player,
                isStarter: player.isStarter,
                currentScore: currentScore,
                projectedScore: projectedScore,
                threatLevel: playerThreat,
                matchupAdvantage: matchupAdvantage,
                percentageOfOpponentTotal: percentageOfTotal
            )
        }
    }
    
    private func calculateThreatLevel(myScore: Double, opponentScore: Double, opponentProjected: Double, topPlayerScore: Double) -> ThreatLevel {
        let scoreDiff = myScore - opponentScore
        
        // Critical: Opponent leading by 15+ OR has player with 25+ points
        if scoreDiff < -15 || topPlayerScore >= 25 {
            return .critical
        }
        
        // High: Opponent leading by 5+ OR projected to outscore by 10+
        if scoreDiff < -5 || (opponentProjected - myScore) > 10 {
            return .high
        }
        
        // Medium: Close game OR opponent projected to win
        if abs(scoreDiff) <= 10 || opponentProjected > myScore {
            return .medium
        }
        
        // Low: You're comfortably ahead
        return .low
    }
    
    private func calculatePlayerThreatLevel(currentScore: Double, projectedScore: Double, position: String) -> PlayerThreatLevel {
        // Position-based thresholds
        let explosiveThreshold: Double
        let dangerousThreshold: Double
        
        switch position.uppercased() {
        case "QB":
            explosiveThreshold = 25
            dangerousThreshold = 18
        case "RB", "WR":
            explosiveThreshold = 20
            dangerousThreshold = 15
        case "TE":
            explosiveThreshold = 18
            dangerousThreshold = 12
        case "K":
            explosiveThreshold = 15
            dangerousThreshold = 10
        default:
            explosiveThreshold = 15
            dangerousThreshold = 10
        }
        
        if currentScore >= explosiveThreshold {
            return .explosive
        } else if currentScore >= dangerousThreshold || projectedScore >= explosiveThreshold {
            return .dangerous
        } else if currentScore >= 8 || projectedScore >= dangerousThreshold {
            return .moderate
        } else {
            return .minimal
        }
    }
    
    private func assessMatchupAdvantage(for player: FantasyPlayer) -> MatchupAdvantage {
        // For now, return neutral - we can enhance this later with matchup data
        // TODO: Integrate with NFL matchup difficulty, weather, etc.
        return .neutral
    }
    
    private func generateStrategicNotes(for matchup: UnifiedMatchup, opponentPlayers: [OpponentPlayer]) -> [String] {
        var notes: [String] = []
        
        // Top performer notes
        if let topPlayer = opponentPlayers.max(by: { $0.currentScore < $1.currentScore }) {
            if topPlayer.currentScore >= 20 {
                notes.append("🔥 \(topPlayer.playerName) is having a monster game (\(topPlayer.scoreDisplay) pts)")
            } else if topPlayer.currentScore <= 3 {
                notes.append("💤 Their top player \(topPlayer.playerName) is struggling (\(topPlayer.scoreDisplay) pts)")
            }
        }
        
        // Game flow analysis
        let totalOpponentScore = opponentPlayers.reduce(0) { $0 + $1.currentScore }
        if totalOpponentScore < 60 {
            notes.append("📉 Opponent having a poor week - maintain aggressive lineup")
        } else if totalOpponentScore > 120 {
            notes.append("🚨 Opponent is exploding - need ceiling plays to keep up")
        }
        
        // Position-specific threats
        let qbs = opponentPlayers.filter { $0.position == "QB" }
        let explosiveQB = qbs.first { $0.currentScore >= 25 }
        if let qb = explosiveQB {
            notes.append("⚡ Their QB \(qb.playerName) is on fire - could be a long day")
        }
        
        return notes
    }
    
    // MARK: - Conflict Detection
    
    private func detectCrossLeagueConflicts(from intelligence: [OpponentIntelligence], matchups: [UnifiedMatchup]) -> [ConflictPlayer] {
        var conflicts: [ConflictPlayer] = []
        
        // Get all my players across all leagues
        let myPlayers = extractMyPlayers(from: matchups)
        
        // Get all opponent players across all leagues
        let opponentPlayers = intelligence.flatMap { intel in
            intel.players.map { ($0, intel.leagueName, intel.opponentTeam.ownerName) }
        }
        
        // Detect conflicts by player ID
        for myPlayerEntry in myPlayers {
            let matchingOpponents = opponentPlayers.filter { $0.0.player.id == myPlayerEntry.player.id }
            
            if !matchingOpponents.isEmpty {
                // Create conflict for this player
                let myLeagues = [LeagueReference(
                    id: myPlayerEntry.leagueId,
                    name: myPlayerEntry.leagueName,
                    isMyTeam: true,
                    opponentName: nil
                )]
                
                let opponentLeagues = matchingOpponents.map { opponent in
                    LeagueReference(
                        id: UUID().uuidString,
                        name: opponent.1,
                        isMyTeam: false,
                        opponentName: opponent.2
                    )
                }
                
                let netImpact = calculateNetImpact(
                    myPlayerScore: myPlayerEntry.player.currentPoints ?? 0.0,
                    opponentInstances: matchingOpponents.count
                )
                
                let severity = determineSeverity(
                    playerScore: myPlayerEntry.player.currentPoints ?? 0.0,
                    conflictCount: matchingOpponents.count + 1
                )
                
                conflicts.append(ConflictPlayer(
                    id: "conflict_\(myPlayerEntry.player.id)",
                    player: myPlayerEntry.player,
                    myLeagues: myLeagues,
                    opponentLeagues: opponentLeagues,
                    conflictType: .ownAndFace,
                    netImpact: netImpact,
                    severity: severity
                ))
            }
        }
        
        return conflicts
    }
    
    private func extractMyPlayers(from matchups: [UnifiedMatchup]) -> [(player: FantasyPlayer, leagueId: String, leagueName: String)] {
        var myPlayers: [(FantasyPlayer, String, String)] = []
        
        for matchup in matchups {
            if let myTeam = matchup.myTeam {
                for player in myTeam.roster where player.isStarter {
                    myPlayers.append((player, matchup.id, matchup.league.league.name))
                }
            }
        }
        
        return myPlayers
    }
    
    private func calculateNetImpact(myPlayerScore: Double, opponentInstances: Int) -> Double {
        // Positive impact from my team, negative impact from opponent teams
        return myPlayerScore - (myPlayerScore * Double(opponentInstances))
    }
    
    private func determineSeverity(playerScore: Double, conflictCount: Int) -> ConflictSeverity {
        let impactScore = playerScore * Double(conflictCount)
        
        if impactScore >= 60 { return .extreme }
        if impactScore >= 40 { return .high }
        if impactScore >= 20 { return .moderate }
        return .low
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cachedIntelligence.removeAll()
        cacheTimestamp = nil
    }
}