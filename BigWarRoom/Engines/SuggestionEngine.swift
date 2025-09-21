//
//  SuggestionEngine.swift
//  DraftWarRoom
//
//  AI-powered suggestion engine for fantasy football drafting strategy
//

import Foundation

struct Suggestion: Identifiable, Hashable {
    let id = UUID()
    let player: Player
    let reasoning: String? // Optional AI reasoning
    
    // Enhanced line with positional ranking
    var line: String { 
        // Get the Sleeper player for positional ranking
        if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: player.id),
           let positionRank = sleeperPlayer.positionalRank {
            return "\(player.firstInitial) \(player.lastName) - \(player.position.rawValue) \(positionRank)"
        } else {
            return "\(player.firstInitial) \(player.lastName) - \(player.position.rawValue)"
        }
    }
}

final class SuggestionEngine {
    private let aiService = AIService.shared
    
    func topSuggestions(
        from available: [Player],
        roster: Roster,
        league: SleeperLeague,
        draft: SleeperDraft,
        picks: [SleeperPick],
        draftRosters: [Int: DraftRosterInfo],
        limit: Int = 20
    ) async throws -> [Suggestion] {
        // Early out if AI usage is disabled
        if AppConstants.useAISuggestions == false {
            return Array(hardcodedTop5(from: available, roster: roster).prefix(limit))
        }

        do {
            let availablePlayerIDs = Set(available.map { $0.id })
            let allSleeperPlayers = PlayerDirectoryStore.shared.players
            let availableSleeperPlayers = allSleeperPlayers.filter { availablePlayerIDs.contains($0.key) }
            
            let currentRoster = SleeperRoster(
                rosterID: 1,
                ownerID: nil,
                leagueID: league.leagueID,
                playerIDs: getPlayerIDs(from: roster),
                draftSlot: nil,
                wins: nil,
                losses: nil,
                ties: nil,
                totalMoves: nil,
                totalMovesMade: nil,
                waiversBudgetUsed: nil,
                settings: nil,
                metadata: nil
            )
            
            let aiSuggestions = try await aiService.fetchTop25Suggestions(
                league: league,
                draft: draft,
                picks: picks,
                roster: currentRoster,
                availablePlayers: availableSleeperPlayers
            )
            
            let suggestions = aiSuggestions.compactMap { aiSuggestion -> Suggestion? in
                guard let player = available.first(where: { $0.id == aiSuggestion.playerID }) else {
                    return nil
                }
                return Suggestion(player: player, reasoning: aiSuggestion.reasoning)
            }
            
            return Array(suggestions.prefix(limit))
        } catch {
            // x// x Print("❌ AI suggestion failed: \(error)")
            return Array(hardcodedTop5(from: available, roster: roster).prefix(limit))
        }
    }
    
    func top5(from available: [Player], roster: Roster, 
              league: SleeperLeague, draft: SleeperDraft, 
              picks: [SleeperPick], draftRosters: [Int: DraftRosterInfo]) async -> [Suggestion] {
        do {
            let result = try await topSuggestions(
                from: available,
                roster: roster,
                league: league,
                draft: draft,
                picks: picks,
                draftRosters: draftRosters,
                limit: 25 // number of picks
            )
            return result
        } catch {
            // x// x Print("❌ AI suggestion failed: \(error)")
            return hardcodedTop5(from: available, roster: roster)
        }
    }
    
    // MARK: -> Fallback Logic (Original Heuristic Engine)
    private func hardcodedTop5(from available: [Player], roster: Roster) -> [Suggestion] {
        // Reuse original scoring logic here
        let weights = Weights()
        
        // Calculate how many picks have been made to estimate round
        let totalPicked = countRosterSpots(roster)
        let estimatedRound = max(1, (totalPicked / 12) + 1) // Assume 12-team league
        
        // Count available players by position for scarcity analysis
        var availableByPosition: [Position: Int] = [:]
        for position in Position.allCases {
            availableByPosition[position] = available.filter { $0.position == position }.count
        }
        
        // Score all available players with smart algorithm
        let allScored = available.map { player -> (Player, Double) in
            let score = score(player: player, roster: roster, availableByPosition: availableByPosition, estimatedRound: estimatedRound, weights: weights)
            return (player, score)
        }
        .sorted { $0.1 > $1.1 }
        
        // For position-filtered lists, just return top 25 by score
        // For "ALL" filter, get balanced suggestions with positional diversity
        let suggestions: [Suggestion]
        if available.isEmpty {
            suggestions = []
        } else if Set(available.map { $0.position }).count == 1 {
            // Single position - just take top 25
            suggestions = Array(allScored.prefix(25)).map { Suggestion(player: $0.0, reasoning: nil) }
        } else {
            // Mixed positions - get balanced selection
            suggestions = getBalancedSuggestions(from: allScored, estimatedRound: estimatedRound)
        }
        
        return suggestions
    }
    
    // MARK: -> Original Scoring Logic (Copied for Fallback)
    private func score(player: Player, roster: Roster, availableByPosition: [Position: Int], estimatedRound: Int, weights: Weights) -> Double {
        var totalScore = 0.0
        
        // 1. ELITE TIER BONUS - Top players are always valuable
        let tierScore = calculateTierScore(player: player, weights: weights)
        totalScore += weights.tierWeight * tierScore
        
        // 2. POSITIONAL SCARCITY - RBs disappear fast, then WRs
        let scarcityScore = calculateScarcityScore(player: player, availableByPosition: availableByPosition, weights: weights)
        totalScore += weights.positionScarcityWeight * scarcityScore
        
        // 3. ROSTER NEED - But be smart about WHEN to fill each position
        let needScore = calculateSmartNeedScore(player: player, roster: roster, round: estimatedRound, weights: weights)
        totalScore += weights.rosterNeedWeight * needScore
        
        // 4. VALUE BUMP - Great players falling to later rounds
        let valueScore = calculateValueScore(player: player, round: estimatedRound, weights: weights)
        totalScore += weights.valueBumpWeight * valueScore
        
        // 5. DRAFT STRATEGY - Skill positions early, everything else later
        let strategyScore = calculateDraftStrategyScore(player: player, round: estimatedRound, weights: weights)
        totalScore += weights.draftRoundStrategy * strategyScore
        
        // 6. TEAM STACKS - Minor bonus for QB/skill player combos
        let stackScore = calculateStackScore(player: player, roster: roster, weights: weights)
        totalScore += weights.stackWeight * stackScore
        
        return totalScore
    }
    
    private func calculateTierScore(player: Player, weights: Weights) -> Double {
        switch player.tier {
        case 1: return 10.0
        case 2: return 7.0
        case 3: return 4.0
        case 4: return 1.0
        default: return 0.5
        }
    }
    
    private func calculateScarcityScore(player: Player, availableByPosition: [Position: Int], weights: Weights) -> Double {
        let available = availableByPosition[player.position] ?? 100
        
        switch player.position {
        case .rb:
            if player.tier <= 2 { return 8.0 }
            if available <= 20 { return 6.0 }
            if available <= 40 { return 4.0 }
            return 2.0
            
        case .wr:
            if player.tier <= 2 { return 7.0 }
            if available <= 30 { return 5.0 }
            if available <= 60 { return 3.0 }
            return 2.0
            
        case .qb:
            if player.tier == 1 { return 4.0 }
            return 1.0
            
        case .te:
            if player.tier <= 2 { return 5.0 }
            return 1.5
            
        case .k, .dst:
            return 0.5
        }
    }
    
    private func calculateSmartNeedScore(player: Player, roster: Roster, round: Int, weights: Weights) -> Double {
        switch player.position {
        case .rb:
            if roster.rb1 == nil { return round <= 3 ? 10.0 : 8.0 }
            if roster.rb2 == nil { return round <= 5 ? 8.0 : 6.0 }
            if roster.flex == nil { return 4.0 }
            return 2.0
            
        case .wr:
            if roster.wr1 == nil { return round <= 2 ? 10.0 : 8.0 }
            if roster.wr2 == nil { return round <= 4 ? 8.0 : 6.0 }
            if roster.wr3 == nil { return round <= 6 ? 6.0 : 4.0 }
            if roster.flex == nil { return 3.0 }
            return 1.5
            
        case .qb:
            if roster.qb == nil {
                if player.tier == 1 && round <= 6 { return 6.0 }
                if round >= 8 { return 8.0 }
                return 2.0
            }
            return 0.5
            
        case .te:
            if roster.te == nil {
                if player.tier <= 2 { return 7.0 }
                if round >= 10 { return 5.0 }
                return 1.0
            }
            return 0.5
            
        case .k:
            if roster.k == nil && round >= 15 { return 3.0 }
            return 0.1
            
        case .dst:
            if roster.dst == nil && round >= 14 { return 3.0 }
            return 0.1
        }
    }
    
    private func calculateValueScore(player: Player, round: Int, weights: Weights) -> Double {
        if player.tier == 1 && round >= 4 { return 5.0 }
        if player.tier == 2 && (player.position == .rb || player.position == .wr) && round >= 7 {
            return 3.0
        }
        return 0.0
    }
    
    private func calculateDraftStrategyScore(player: Player, round: Int, weights: Weights) -> Double {
        switch player.position {
        case .rb, .wr:
            if round <= 6 { return 5.0 }
            if round <= 10 { return 3.0 }
            return 2.0
            
        case .qb:
            if player.tier == 1 && round <= 6 { return 3.0 }
            if round >= 8 && round <= 12 { return 4.0 }
            if round >= 5 && round <= 7 { return 1.0 }
            return 2.0
            
        case .te:
            if player.tier <= 2 && round <= 6 { return 4.0 }
            if round >= 10 { return 3.0 }
            return 1.0
            
        case .k, .dst:
            if round >= 14 { return 2.0 }
            return 0.1
        }
    }
    
    private func calculateStackScore(player: Player, roster: Roster, weights: Weights) -> Double {
        let ownedQBTeams = Set([roster.qb?.team].compactMap { $0 })
        let ownedSkillTeams = Set([roster.rb1?.team, roster.rb2?.team, roster.wr1?.team, roster.wr2?.team, roster.wr3?.team, roster.te?.team, roster.flex?.team].compactMap { $0 })
        
        switch player.position {
        case .qb:
            return ownedSkillTeams.contains(player.team) ? 2.0 : 0.0
        case .rb, .wr, .te:
            return ownedQBTeams.contains(player.team) ? 2.0 : 0.0
        default:
            return 0.0
        }
    }
    
    private func getBalancedSuggestions(from allScored: [(Player, Double)], estimatedRound: Int) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        var positionCounts: [Position: Int] = [:]
        
        let maxPerPosition: [Position: Int] = [
            .rb: 8, .wr: 10, .qb: 4, .te: 4, .k: 2, .dst: 2
        ]
        
        for (player, _) in allScored {
            guard suggestions.count < 25 else { break }
            
            let currentCount = positionCounts[player.position] ?? 0
            let maxAllowed = maxPerPosition[player.position] ?? 5
            
            guard currentCount < maxAllowed else { continue }
            
            if (player.position == .k || player.position == .dst) && estimatedRound < 14 {
                continue
            }
            
            suggestions.append(Suggestion(player: player, reasoning: nil))
            positionCounts[player.position] = currentCount + 1
        }
        
        if suggestions.count < 25 {
            let usedPlayerIDs = Set(suggestions.map { $0.player.id })
            for (player, _) in allScored {
                guard suggestions.count < 25 else { break }
                guard !usedPlayerIDs.contains(player.id) else { continue }
                
                if (player.position == .k || player.position == .dst) && estimatedRound < 14 {
                    continue
                }
                
                suggestions.append(Suggestion(player: player, reasoning: nil))
            }
        }
        
        return suggestions
    }
    
    private func countRosterSpots(_ roster: Roster) -> Int {
        var count = 0
        if roster.qb != nil { count += 1 }
        if roster.rb1 != nil { count += 1 }
        if roster.rb2 != nil { count += 1 }
        if roster.wr1 != nil { count += 1 }
        if roster.wr2 != nil { count += 1 }
        if roster.wr3 != nil { count += 1 }
        if roster.te != nil { count += 1 }
        if roster.flex != nil { count += 1 }
        if roster.k != nil { count += 1 }
        if roster.dst != nil { count += 1 }
        count += roster.bench.count
        return count
    }
    
    private func getPlayerIDs(from roster: Roster) -> [String] {
        var ids: [String] = []
        if let qb = roster.qb { ids.append(qb.id) }
        if let rb1 = roster.rb1 { ids.append(rb1.id) }
        if let rb2 = roster.rb2 { ids.append(rb2.id) }
        if let wr1 = roster.wr1 { ids.append(wr1.id) }
        if let wr2 = roster.wr2 { ids.append(wr2.id) }
        if let wr3 = roster.wr3 { ids.append(wr3.id) }
        if let te = roster.te { ids.append(te.id) }
        if let flex = roster.flex { ids.append(flex.id) }
        if let k = roster.k { ids.append(k.id) }
        if let dst = roster.dst { ids.append(dst.id) }
        ids.append(contentsOf: roster.bench.map { $0.id })
        return ids
    }
    
    // MARK: -> Weights (Copied for Fallback)
    struct Weights {
        var tierWeight: Double = 2.0
        var positionScarcityWeight: Double = 1.5
        var rosterNeedWeight: Double = 1.2
        var valueBumpWeight: Double = 0.8
        var draftRoundStrategy: Double = 1.0
        var stackWeight: Double = 0.3
    }
}
