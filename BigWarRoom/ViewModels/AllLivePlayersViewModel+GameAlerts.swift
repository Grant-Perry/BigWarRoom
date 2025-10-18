//
//  AllLivePlayersViewModel+GameAlerts.swift
//  BigWarRoom
//
//  🚨 FOCUSED: Game alerts integration for tracking highest scoring plays per refresh
//

import Foundation

extension AllLivePlayersViewModel {
    // MARK: - Game Alerts Properties
    
    /// Storage for player scores before refresh (to calculate deltas)
    private var previousPlayerScores: [String: Double] {
        get {
            if let data = UserDefaults.standard.data(forKey: "AllLivePlayers_PreviousScores"),
               let scores = try? JSONDecoder().decode([String: Double].self, from: data) {
                return scores
            }
            return [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "AllLivePlayers_PreviousScores")
            }
        }
    }
    
    // MARK: - Game Alerts Integration
    
    /// Capture player scores before refresh and check for highest scoring play after refresh
    internal func processGameAlerts(from playerEntries: [LivePlayerEntry]) {
        // Get previous scores for comparison
        let prevScores = previousPlayerScores
        
        // Start new refresh cycle
        GameAlertsManager.shared.startNewRefreshCycle()
        
        print("🚨 GAME ALERTS DEBUG: Processing \(playerEntries.count) players, have \(prevScores.count) previous scores")
        
        // Find the highest scoring play (biggest delta) in this refresh
        var highestScoringPlay: (entry: LivePlayerEntry, pointsGained: Double)? = nil
        var allDeltas: [(String, Double)] = []
        
        for entry in playerEntries {
            let currentScore = entry.currentScore
            let previousScore = prevScores[entry.player.id] ?? 0.0
            let pointsGained = currentScore - previousScore
            
            // Track all deltas for debugging
            if pointsGained != 0.0 {
                allDeltas.append((entry.playerName, pointsGained))
            }
            
            // LOWERED THRESHOLD: Only consider gains > 0.01 points (was 0.1)
            if pointsGained > 0.01 {
                if highestScoringPlay == nil || pointsGained > highestScoringPlay!.pointsGained {
                    highestScoringPlay = (entry, pointsGained)
                }
            }
        }
        
        // Log all significant deltas for debugging
        let positiveDeltas = allDeltas.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        if positiveDeltas.count > 0 {
            print("🚨 GAME ALERTS DEBUG: Top 5 positive deltas this refresh:")
            for (i, delta) in positiveDeltas.prefix(5).enumerated() {
                print("   \(i+1). \(delta.0): +\(String(format: "%.2f", delta.1)) pts")
            }
        } else {
            print("🚨 GAME ALERTS DEBUG: No positive deltas found this refresh")
        }
        
        // Add game alert for highest scoring play
        if let highestPlay = highestScoringPlay {
            GameAlertsManager.shared.addAlert(
                playerName: highestPlay.entry.playerName,
                playerPosition: highestPlay.entry.position,
                playerTeam: highestPlay.entry.player.team,
                pointsScored: highestPlay.pointsGained,
                leagueName: highestPlay.entry.leagueName
            )
            print("🚨 GAME ALERT CREATED: \(highestPlay.entry.playerName) +\(String(format: "%.2f", highestPlay.pointsGained)) pts")
        } else {
            print("🚨 GAME ALERTS DEBUG: No qualifying play found (all deltas < 0.01 pts)")
        }
        
        // Update previous scores for next refresh
        var newPreviousScores: [String: Double] = [:]
        for entry in playerEntries {
            newPreviousScores[entry.player.id] = entry.currentScore
        }
        previousPlayerScores = newPreviousScores
        
        print("🚨 GAME ALERTS DEBUG: Stored \(newPreviousScores.count) player scores for next refresh")
    }
    
    /// Clear game alerts and reset previous scores (for testing)
    func clearGameAlertsData() {
        GameAlertsManager.shared.clearAlerts()
        previousPlayerScores = [:]
        print("🗑️ GAME ALERTS: Cleared all alerts and previous scores")
    }
    
    /// Test the game alerts system with direct manager calls (for development)
    func testGameAlerts() {
        // Simulate a series of refreshes with different high scorers
        
        // First refresh - Ja'Marr Chase big play
        GameAlertsManager.shared.startNewRefreshCycle()
        GameAlertsManager.shared.addAlert(
            playerName: "Ja'Marr Chase",
            playerPosition: "WR",
            playerTeam: "CIN", 
            pointsScored: 18.32,
            leagueName: "Main League"
        )
        
        // Second refresh - Derrick Henry TD
        GameAlertsManager.shared.startNewRefreshCycle()
        GameAlertsManager.shared.addAlert(
            playerName: "Derrick Henry",
            playerPosition: "RB",
            playerTeam: "BAL",
            pointsScored: 12.40,
            leagueName: "Work League"
        )
        
        // Third refresh - Josh Allen rushing TD
        GameAlertsManager.shared.startNewRefreshCycle()
        GameAlertsManager.shared.addAlert(
            playerName: "Josh Allen",
            playerPosition: "QB",
            playerTeam: "BUF",
            pointsScored: 8.75,
            leagueName: "Friends League"
        )
        
        print("🧪 GAME ALERTS: Added test alerts for 3 refresh cycles")
    }
}