//
//  GameAlertsFileManager.swift
//  BigWarRoom
//
//  🔥 LOCAL FILE STORAGE for GameAlerts data
//  Replaces UserDefaults to prevent 4MB+ overflow crashes
//

import Foundation

/// **GameAlertsFileManager**
/// 
/// Handles local file storage for GameAlerts data to prevent UserDefaults overflow.
/// Stores player scores and alert data in JSON files in the Documents directory.
@MainActor
final class GameAlertsFileManager {
    
    // MARK: - Singleton
    static let shared = GameAlertsFileManager()
    private init() {
        createDirectoryIfNeeded()
    }
    
    // MARK: - File URLs
    
    /// Base directory for GameAlerts data
    private var gameAlertsDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("GameAlerts")
    }
    
    /// File for storing previous player scores
    private var previousScoresURL: URL {
        gameAlertsDirectory.appendingPathComponent("PreviousScores.json")
    }
    
    /// File for storing alert history (future use)
    private var alertHistoryURL: URL {
        gameAlertsDirectory.appendingPathComponent("AlertsHistory.json")
    }
    
    // MARK: - Directory Management
    
    /// Create GameAlerts directory if it doesn't exist
    private func createDirectoryIfNeeded() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: gameAlertsDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: gameAlertsDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                if AppConstants.debug {
                }
            } catch {
            }
        }
    }
    
    // MARK: - Previous Scores Storage
    
    /// Load previous player scores from file
    func loadPreviousScores() -> [String: Double] {
        guard FileManager.default.fileExists(atPath: previousScoresURL.path) else {
            if AppConstants.debug {
            }
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: previousScoresURL)
            let scores = try JSONDecoder().decode([String: Double].self, from: data)
            
            if AppConstants.debug {
            }
            
            return scores
        } catch {
            return [:]
        }
    }
    
    /// Save previous player scores to file
    func savePreviousScores(_ scores: [String: Double]) {
        do {
            let data = try JSONEncoder().encode(scores)
            try data.write(to: previousScoresURL)
            
            if AppConstants.debug {
            }
        } catch {
        }
    }
    
    // MARK: - Migration from UserDefaults
    
    /// Migrate existing GameAlerts data from UserDefaults to local files
    func migrateFromUserDefaults() {
        let userDefaultsKey = "AllLivePlayers_PreviousScores"
        
        // Check if UserDefaults has the old data
        guard let userData = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            if AppConstants.debug {
            }
            return
        }
        
        do {
            // Decode the UserDefaults data
            let existingScores = try JSONDecoder().decode([String: Double].self, from: userData)
            
            // Save to file
            savePreviousScores(existingScores)
            
            // Remove from UserDefaults to free up space
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            UserDefaults.standard.synchronize()
            
            if AppConstants.debug {
            }
        } catch {
            
            // Still remove the corrupted UserDefaults data to prevent crashes
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            UserDefaults.standard.synchronize()
            
        }
    }
    
    // MARK: - Cleanup Utilities
    
    /// Clear all GameAlerts file data (for testing/reset)
    func clearAllData() {
        let fileManager = FileManager.default
        
        do {
            if fileManager.fileExists(atPath: previousScoresURL.path) {
                try fileManager.removeItem(at: previousScoresURL)
            }
            
            if fileManager.fileExists(atPath: alertHistoryURL.path) {
                try fileManager.removeItem(at: alertHistoryURL)
            }
            
            if AppConstants.debug {
            }
        } catch {
        }
    }
    
    /// Get file sizes for debugging
    func getStorageInfo() -> (previousScoresSize: Int, totalSize: Int) {
        let fileManager = FileManager.default
        var previousScoresSize = 0
        var totalSize = 0
        
        // Check previous scores file size
        if fileManager.fileExists(atPath: previousScoresURL.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: previousScoresURL.path)
                previousScoresSize = attributes[.size] as? Int ?? 0
            } catch {
            }
        }
        
        totalSize = previousScoresSize // Add other files when implemented
        
        return (previousScoresSize: previousScoresSize, totalSize: totalSize)
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension GameAlertsFileManager {
    /// Debug: Print file storage information
    func printStorageInfo() {
        let info = getStorageInfo()
        let previousKB = Double(info.previousScoresSize) / 1024.0
        let totalKB = Double(info.totalSize) / 1024.0
        
    }
    
    /// Debug: Print sample of stored data
    func printSampleData() {
        let scores = loadPreviousScores()
        let sampleScores = Array(scores.prefix(5))
        
        for (playerId, score) in sampleScores {
        }
    }
}
#endif