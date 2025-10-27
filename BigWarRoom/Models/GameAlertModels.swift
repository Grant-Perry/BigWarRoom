//
//  GameAlertModels.swift
//  BigWarRoom
//
//  Models for tracking highest scoring plays per refresh cycle
//

import Foundation
import SwiftUI
import Observation

/// Model for a single game alert representing the highest scoring play in a refresh cycle
struct GameAlert: Identifiable {
    let id: String
    let playerName: String
    let playerPosition: String
    let playerTeam: String?
    let pointsScored: Double
    let leagueName: String
    let timestamp: Date
    let refreshCycle: Int // Track which refresh cycle this came from
    
    /// Points scored formatted for display
    var pointsDisplay: String {
        return String(format: "%.2f", pointsScored)
    }
    
    /// Time ago display
    var timeAgoDisplay: String {
        let interval = Date().timeIntervalSince(timestamp)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
    
    /// Team color for display
    var teamColor: Color {
        if let team = playerTeam {
            return NFLTeamColors.color(for: team)
        }
        return NFLTeamColors.fallbackColor(for: playerPosition)
    }
    
    /// Alert display text
    var alertText: String {
        let teamInfo = playerTeam ?? playerPosition
        return "\(playerName) (\(teamInfo)) scored \(pointsDisplay) pts"
    }
}

/// Manager for tracking and storing game alerts
@Observable
@MainActor
final class GameAlertsManager {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: GameAlertsManager?
    
    static var shared: GameAlertsManager {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = GameAlertsManager()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: GameAlertsManager) {
        _shared = instance
    }
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var alerts: [GameAlert] = []
    var currentRefreshCycle: Int = 0
    
    // MARK: - Constants
    private let maxAlerts = 50
    
    // MARK: - Initialization
    
    // 🔥 PHASE 2.5: Default initializer for bridge pattern
    init() {}
    
    // MARK: - Public Methods
    
    /// Add a new game alert for the highest scoring player in this refresh
    func addAlert(
        playerName: String,
        playerPosition: String,
        playerTeam: String?,
        pointsScored: Double,
        leagueName: String
    ) {
        // Only add if points are meaningful (> 0.1 to avoid tiny updates)
        guard pointsScored > 0.1 else { return }
        
        let alert = GameAlert(
            id: UUID().uuidString,
            playerName: playerName,
            playerPosition: playerPosition,
            playerTeam: playerTeam,
            pointsScored: pointsScored,
            leagueName: leagueName,
            timestamp: Date(),
            refreshCycle: currentRefreshCycle
        )
        
        // Add to front of list (most recent first)
        alerts.insert(alert, at: 0)
        
        // Trim to max alerts
        if alerts.count > maxAlerts {
            alerts = Array(alerts.prefix(maxAlerts))
        }
    }
    
    /// Add some test alerts for testing the UI
    func addTestAlerts() {
        // Clear existing alerts first
        alerts.removeAll()
        
        // Add some realistic test alerts
        addAlert(
            playerName: "Ja'Marr Chase",
            playerPosition: "WR",
            playerTeam: "CIN",
            pointsScored: 18.32,
            leagueName: "Main League"
        )
        
        addAlert(
            playerName: "Derrick Henry",
            playerPosition: "RB", 
            playerTeam: "BAL",
            pointsScored: 12.40,
            leagueName: "Work League"
        )
        
        addAlert(
            playerName: "Josh Allen",
            playerPosition: "QB",
            playerTeam: "BUF", 
            pointsScored: 8.75,
            leagueName: "Friends League"
        )
        
        addAlert(
            playerName: "Travis Kelce",
            playerPosition: "TE",
            playerTeam: "KC",
            pointsScored: 15.60,
            leagueName: "Dynasty League"
        )
    }
    
    /// Start a new refresh cycle
    func startNewRefreshCycle() {
        currentRefreshCycle += 1
    }
    
    /// Clear all alerts (for testing)
    func clearAlerts() {
        alerts.removeAll()
        currentRefreshCycle = 0
    }
    
    /// Get alerts for current session
    var sessionAlerts: [GameAlert] {
        return alerts
    }
    
    /// Check if we have any alerts
    var hasAlerts: Bool {
        return !alerts.isEmpty
    }
    
    /// Get count of alerts
    var alertCount: Int {
        return alerts.count
    }
}