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
        
        // Find the highest scoring play (biggest delta) in this refresh
        var highestScoringPlay: (entry: LivePlayerEntry, pointsGained: Double)? = nil
        
        for entry in playerEntries {
            let currentScore = entry.currentScore
            let previousScore = prevScores[entry.player.id] ?? 0.0
            let pointsGained = currentScore - previousScore
            
            // LOWERED THRESHOLD: Only consider gains > 0.01 points (was 0.1)
            if pointsGained > 0.01 {
                if highestScoringPlay == nil || pointsGained > highestScoringPlay!.pointsGained {
                    highestScoringPlay = (entry, pointsGained)
                }
            }
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
        }
        
        // Update previous scores for next refresh
        var newPreviousScores: [String: Double] = [:]
        for entry in playerEntries {
            newPreviousScores[entry.player.id] = entry.currentScore
        }
        previousPlayerScores = newPreviousScores
    }
    
    /// Clear game alerts and reset previous scores (for testing)
    func clearGameAlertsData() {
        GameAlertsManager.shared.clearAlerts()
        previousPlayerScores = [:]
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
    }
}