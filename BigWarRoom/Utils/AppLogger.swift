//
//  AppLogger.swift
//  BigWarRoom
//
//  🔥 UNIFIED: Proper logging system to replace all print statements
//

import Foundation
import os.log

/// Unified logging system for BigWarRoom
enum AppLogger {
    private static let logger = Logger(subsystem: "com.bigwarroom.app", category: "BigWarRoom")
    
    /// Log levels for different types of messages
    enum Level {
        case debug
        case info
        case warning
        case error
        case critical
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    /// Log a message with specified level
    static func log(_ message: String, level: Level = .info, category: String = "General") {
        #if DEBUG
        // In debug builds, also print to console for Xcode visibility
        print("\(level.emoji) [\(category)] \(message)")
        #endif
        
        // Always log to unified logging system
        logger.log(level: level.osLogType, "\(category, privacy: .public): \(message, privacy: .public)")
    }
    
    /// Convenience methods for different log levels
    static func debug(_ message: String, category: String = "Debug") {
        log(message, level: .debug, category: category)
    }
    
    static func info(_ message: String, category: String = "Info") {
        log(message, level: .info, category: category)
    }
    
    static func warning(_ message: String, category: String = "Warning") {
        log(message, level: .warning, category: category)
    }
    
    static func error(_ message: String, category: String = "Error") {
        log(message, level: .error, category: category)
    }
    
    static func critical(_ message: String, category: String = "Critical") {
        log(message, level: .critical, category: category)
    }
}

/// Convenience global functions for cleaner syntax
//func logDebug(_ message: String, category: String = "Debug") {
//    AppLogger.debug(message, category: category)
//}

func logInfo(_ message: String, category: String = "Info") {
    AppLogger.info(message, category: category)
}

func logWarning(_ message: String, category: String = "Warning") {
    AppLogger.warning(message, category: category)
}

func logError(_ message: String, category: String = "Error") {
    AppLogger.error(message, category: category)
}

func logCritical(_ message: String, category: String = "Critical") {
    AppLogger.critical(message, category: category)
}
