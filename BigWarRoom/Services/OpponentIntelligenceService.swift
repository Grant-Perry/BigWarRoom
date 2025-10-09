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
        
        // Critical threat recommendations
        let criticalThreats = intelligence.filter { $0.threatLevel == .critical }
        for threat in criticalThreats {
            recommendations.append(StrategicRecommendation(
                type: .threatAssessment,
                title: "🚨 Critical Threat Alert",
                description: "You're losing to \(threat.opponentTeam.ownerName) by \(abs(threat.scoreDifferential).formatted(.number.precision(.fractionLength(1)))) points in \(threat.leagueName)",
                priority: .critical,
                actionable: true
            ))
        }
        
        // Conflict warnings
        let majorConflicts = intelligence.flatMap { $0.conflictPlayers.filter { $0.severity == .extreme || $0.severity == .high } }
        for conflict in majorConflicts {
            let action = conflict.netImpact > 0 ? "START" : "BENCH"
            recommendations.append(StrategicRecommendation(
                type: .conflictWarning,
                title: "⚖️ Player Conflict Detected",
                description: "\(action) \(conflict.player.fullName) - \(conflict.recommendation)",
                priority: conflict.severity == .extreme ? .critical : .high,
                actionable: true
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
                actionable: false
            ))
        }
        
        // Sort by priority
        return recommendations.sorted { $0.priority.rawValue < $1.priority.rawValue }
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