//
//  PlayerWatchModels.swift
//  BigWarRoom
//
//  Models for the Player Watch system - track opponent players in real-time
//

import Foundation
import SwiftUI

// MARK: - Core Watch Models

/// A player being actively monitored for score changes
struct WatchedPlayer: Identifiable, Codable {
    let id: String
    let playerID: String
    let playerName: String
    let position: String
    let team: String?
    let watchStartTime: Date
    let initialScore: Double
    let opponentReferences: [OpponentReference]
    
    // Dynamic properties (not stored)
    var currentScore: Double = 0.0
    var isLive: Bool = false
    
    /// Score change since watching started
    var deltaScore: Double {
        currentScore - initialScore
    }
    
    /// Delta formatted for display
    var deltaDisplay: String {
        let delta = deltaScore
        if delta > 0 {
            return "+\(String(format: "%.1f", delta))"
        } else if delta < 0 {
            return String(format: "%.1f", delta)
        } else {
            return "±0.0"
        }
    }
    
    /// Delta color based on performance
    var deltaColor: Color {
        if deltaScore > 0 {
            return .red // Bad for us - opponent player scoring
        } else if deltaScore < 0 {
            return .green // Good for us - opponent player struggling
        } else {
            return .gray
        }
    }
    
    /// Time since watching started
    var watchDuration: TimeInterval {
        Date().timeIntervalSince(watchStartTime)
    }
    
    /// Formatted watch duration
    var watchDurationString: String {
        let minutes = Int(watchDuration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    /// Threat level based on delta performance
    var currentThreatLevel: WatchThreatLevel {
        switch deltaScore {
        case 15...:
            return .critical
        case 10..<15:
            return .high
        case 5..<10:
            return .moderate
        case 0..<5:
            return .minimal
        default: // Negative scores
            return .beneficial
        }
    }
    
    /// How many opponents own this player
    var opponentCount: Int {
        opponentReferences.count
    }
    
    /// Impact multiplier based on how many opponents own this player
    var impactMultiplier: Double {
        switch opponentCount {
        case 1: return 1.0
        case 2: return 1.5
        case 3...: return 2.0
        default: return 1.0
        }
    }
    
    /// Weighted threat score (delta * impact multiplier)
    var weightedThreatScore: Double {
        max(0, deltaScore * impactMultiplier)
    }
}

/// Reference to an opponent who owns a watched player
struct OpponentReference: Identifiable, Codable {
    let id: String
    let opponentName: String
    let leagueName: String
    let leagueSource: String
    
    // Convenience computed property to get LeagueSource
    var leagueSourceEnum: LeagueSource {
        LeagueSource(rawValue: leagueSource) ?? .sleeper
    }
}

/// Threat level for watched player performance
enum WatchThreatLevel: String, CaseIterable {
    case beneficial = "BENEFICIAL"
    case minimal = "MINIMAL"
    case moderate = "MODERATE"
    case high = "HIGH"
    case critical = "CRITICAL"
    
    var color: Color {
        switch self {
        case .beneficial: return .green
        case .minimal: return .gray
        case .moderate: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var emoji: String {
        switch self {
        case .beneficial: return "✅"
        case .minimal: return "😐"
        case .moderate: return "⚡"
        case .high: return "⚠️"
        case .critical: return "🚨"
        }
    }
    
    var description: String {
        switch self {
        case .beneficial: return "Opponent player struggling - good for you!"
        case .minimal: return "Minimal impact so far"
        case .moderate: return "Moderate performance - keep watching"
        case .high: return "Strong performance - concerning"
        case .critical: return "Explosive performance - major threat!"
        }
    }
}

// MARK: - Watch Notification Models

/// Notification triggered by watched player performance
struct WatchNotification: Identifiable {
    let id = UUID()
    let watchedPlayer: WatchedPlayer
    let notificationType: NotificationType
    let timestamp: Date
    let deltaAtNotification: Double
    
    enum NotificationType: String, CaseIterable {
        case notable = "NOTABLE"
        case significant = "SIGNIFICANT"
        case critical = "CRITICAL"
        case explosive = "EXPLOSIVE"
        
        var threshold: Double {
            switch self {
            case .notable: return 5.0
            case .significant: return 10.0
            case .critical: return 15.0
            case .explosive: return 20.0
            }
        }
        
        var emoji: String {
            switch self {
            case .notable: return "🟡"
            case .significant: return "🟠"
            case .critical: return "🔴"
            case .explosive: return "💥"
            }
        }
        
        var priority: NotificationPriority {
            switch self {
            case .notable: return .low
            case .significant: return .medium
            case .critical: return .high
            case .explosive: return .urgent
            }
        }
    }
    
    enum NotificationPriority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case urgent = 4
        
        var shouldVibrate: Bool {
            return self == .high || self == .urgent
        }
        
        var shouldPlaySound: Bool {
            return self == .urgent
        }
    }
    
    /// Formatted notification message
    var message: String {
        let playerName = watchedPlayer.playerName
        let delta = watchedPlayer.deltaDisplay
        let opponentCount = watchedPlayer.opponentCount
        
        switch notificationType {
        case .notable:
            return "🟡 \(playerName) \(delta) pts since watching"
        case .significant:
            return "🟠 \(playerName) heating up: \(delta) pts"
        case .critical:
            if opponentCount > 1 {
                return "🔴 ALERT: \(playerName) exploding \(delta) pts - hurting you in \(opponentCount) leagues!"
            } else {
                return "🔴 ALERT: \(playerName) exploding \(delta) pts"
            }
        case .explosive:
            return "💥 EXPLOSIVE: \(playerName) \(delta) pts - MAJOR THREAT!"
        }
    }
}

// MARK: - Watch Settings

/// User preferences for watch notifications and behavior
struct WatchSettings: Codable {
    var notificationSensitivity: NotificationSensitivity = .normal
    var enableNotifications: Bool = true
    var enableVibration: Bool = true
    var enableSound: Bool = false
    var autoUnwatchAfterGames: Bool = true
    var maxWatchedPlayers: Int = 25 // Increased from 10 to 25
    var clearWatchedPlayersOnWeekChange: Bool = true // Clear watches when week changes
    
    enum NotificationSensitivity: String, CaseIterable, Codable {
        case conservative = "Conservative"
        case normal = "Normal"
        case aggressive = "Aggressive"
        
        var thresholdMultiplier: Double {
            switch self {
            case .conservative: return 1.5 // Higher thresholds
            case .normal: return 1.0 // Default thresholds
            case .aggressive: return 0.7 // Lower thresholds
            }
        }
        
        var description: String {
            switch self {
            case .conservative: return "Fewer notifications, only major events"
            case .normal: return "Balanced notification frequency"
            case .aggressive: return "More notifications, catch every movement"
            }
        }
    }
}

// MARK: - Watch Statistics

/// Analytics for watch performance and user behavior
struct WatchStatistics {
    let totalPlayersWatched: Int
    let averageWatchDuration: TimeInterval
    let mostWatchedPosition: String
    let biggestDeltaCaught: Double
    let totalNotificationsSent: Int
    let accuracyRate: Double // How often watched players actually became threats
    
    /// Formatted statistics for display
    var formattedAverageWatchDuration: String {
        let minutes = Int(averageWatchDuration / 60)
        return "\(minutes) minutes"
    }
    
    var formattedAccuracyRate: String {
        return "\(Int(accuracyRate * 100))%"
    }
}