import Foundation
import os.log

/// Centralized debug logging utility with toggleable debug modes
enum DebugLogger {
    
    // MARK: - Debug Flags
    /// Master debug switch - set to false to disable ALL debug logging
    private static let isDebugEnabled = false
    
    /// Specific debug categories - can be toggled independently
    private static let debugCategories: Set<DebugCategory> = []
    
    // MARK: - Debug Categories
    enum DebugCategory: String, CaseIterable {
        case api = "API"
        case draft = "DRAFT" 
        case fantasy = "FANTASY"
        case matchups = "MATCHUPS"
        case authentication = "AUTH"
        case scoring = "SCORING"
        case playerStats = "STATS"
        case ui = "UI"
        case general = "GENERAL"
        
        var emoji: String {
            switch self {
            case .api: return "📡"
            case .draft: return "🏈"
            case .fantasy: return "⭐"
            case .matchups: return "⚔️"
            case .authentication: return "🔐"
            case .scoring: return "📊"
            case .playerStats: return "👤"
            case .ui: return "🖥️"
            case .general: return "🔍"
            }
        }
    }
    
    // MARK: - Log Levels
    enum LogLevel {
        case debug
        case info
        case warning
        case error
        
        var emoji: String {
            switch self {
            case .debug: return "🐛"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message with category
    static func log(_ message: String, category: DebugCategory = .general, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebugEnabled && (debugCategories.isEmpty || debugCategories.contains(category)) else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.debugTimestamp.string(from: Date())
        let logMessage = "\(timestamp) \(level.emoji) [\(category.rawValue)] \(category.emoji) \(message) (\(fileName):\(line))"
        
        print(logMessage)
    }
    
    /// Log API-related messages
    static func api(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .api, level: level, file: file, function: function, line: line)
    }
    
    /// Log draft-related messages
    static func draft(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .draft, level: level, file: file, function: function, line: line)
    }
    
    /// Log fantasy-related messages
    static func fantasy(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .fantasy, level: level, file: file, function: function, line: line)
    }
    
    /// Log matchup-related messages
    static func matchups(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .matchups, level: level, file: file, function: function, line: line)
    }
    
    /// Log authentication-related messages
    static func auth(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .authentication, level: level, file: file, function: function, line: line)
    }
    
    /// Log scoring-related messages
    static func scoring(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .scoring, level: level, file: file, function: function, line: line)
    }
    
    /// Log player stats-related messages
    static func stats(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .playerStats, level: level, file: file, function: function, line: line)
    }
    
    /// Log UI-related messages
    static func ui(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .ui, level: level, file: file, function: function, line: line)
    }
    
    // MARK: - Quick Methods for Common Cases
    
    /// Log errors that should always be visible (regardless of debug settings)
    static func error(_ message: String, category: DebugCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        // Errors always print regardless of debug settings
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.debugTimestamp.string(from: Date())
        let logMessage = "\(timestamp) ❌ [\(category.rawValue)] \(category.emoji) \(message) (\(fileName):\(line))"
        print(logMessage)
    }
    
    /// Log warnings that should always be visible (regardless of debug settings)  
    static func warning(_ message: String, category: DebugCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        // Warnings always print regardless of debug settings
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.debugTimestamp.string(from: Date())
        let logMessage = "\(timestamp) ⚠️ [\(category.rawValue)] \(category.emoji) \(message) (\(fileName):\(line))"
        print(logMessage)
    }
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let debugTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}