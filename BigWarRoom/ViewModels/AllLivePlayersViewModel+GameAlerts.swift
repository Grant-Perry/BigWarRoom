//
//  AllLivePlayersViewModel+GameAlerts.swift
//  BigWarRoom
//
//  🚨 FOCUSED: Game alerts integration for tracking highest scoring plays per refresh
//

import Foundation

// 🔥 MIGRATION FLAG: Use class-level storage for migration tracking
private class GameAlertsMigration {
    static var hasRunMigration = false
}

extension AllLivePlayersViewModel {
    // MARK: - Game Alerts Properties
    
    // 🔥 CRITICAL FIX: Use local file storage instead of UserDefaults to prevent 4MB+ overflow
    /// Storage for player scores before refresh (to calculate deltas)
    private var previousPlayerScores: [String: Double] {
        get {
            return GameAlertsFileManager.shared.loadPreviousScores()
        }
        set {
            GameAlertsFileManager.shared.savePreviousScores(newValue)
        }
    }
    
    // MARK: - Game Alerts Integration
    
    /// Capture player scores before refresh and check for highest scoring play after refresh
    internal func processGameAlerts(from playerEntries: [LivePlayerEntry]) {
        // 🔥 MIGRATE: On first run, migrate any existing UserDefaults data
        if !GameAlertsMigration.hasRunMigration {
            GameAlertsFileManager.shared.migrateFromUserDefaults()
            GameAlertsMigration.hasRunMigration = true
        }
        
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
        
        // Update previous scores for next refresh (FILE STORAGE)
        var newPreviousScores: [String: Double] = [:]
        for entry in playerEntries {
            newPreviousScores[entry.player.id] = entry.currentScore
        }
        previousPlayerScores = newPreviousScores
        
        // 🔥 DEBUG: Log file storage info
        if AppConstants.debug {
            let info = GameAlertsFileManager.shared.getStorageInfo()
            let sizeKB = Double(info.totalSize) / 1024.0
            print("🚨 GAME ALERTS: Updated file storage with \(newPreviousScores.count) player scores (\(String(format: "%.2f", sizeKB)) KB)")
        }
    }
    
    /// Clear game alerts and reset previous scores (for testing)
    func clearGameAlertsData() {
        GameAlertsManager.shared.clearAlerts()
        GameAlertsFileManager.shared.clearAllData()
        
        if AppConstants.debug {
            print("🚨 GAME ALERTS: Cleared all file storage and GameAlerts data")
        }
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
    
    // MARK: - Debug Utilities
    
    /// Print GameAlerts file storage information (debug only)
    func debugGameAlertsStorage() {
        #if DEBUG
        GameAlertsFileManager.shared.printStorageInfo()
        GameAlertsFileManager.shared.printSampleData()
        #endif
    }
}