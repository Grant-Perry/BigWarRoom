import Foundation
import os.log

//  MARK: NOTICE: STOP USING THIS METHOD - it is depreciated. Use DebugPrint() instead

/// Centralized debug logging utility with toggleable debug modes
enum DebugLogger {

    // MARK: - Debug Flags
    /// Master debug switch - set to false to disable ALL debug logging
    private static let isDebugEnabled = false

    /// Specific debug categories - can be toggled independently
    private static let debugCategories: Set<DebugCategory> = [.fantasy] // just add the DebugCategory you want to add .api or many [.api, .scoring, .ui]

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
        case playerIDMapping = "PLAYER_ID_MAPPING"
        
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
            case .playerIDMapping: return "🆔"
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
    
    /// Log player ID mapping-related messages
    static func playerIDMapping(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: .playerIDMapping, level: level, file: file, function: function, line: line)
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

// MARK: - NEW: Flexible Debug Mode System (OptionSet-based)

/// Debug mode flags - combine multiple modes to focus on specific areas
struct DebugMode: OptionSet {
    let rawValue: Int
    
    // MARK: debugMode definitions

    static let none               	= DebugMode([])
    static let globalRefresh		= DebugMode(rawValue: 1 << 0)  // 1
    static let espnAPI           	= DebugMode(rawValue: 1 << 1)  // 2
    static let sleeperAPI         	= DebugMode(rawValue: 1 << 2)  // 4
    static let matchupLoading     	= DebugMode(rawValue: 1 << 3)  // 8
    static let recordCalculation  	= DebugMode(rawValue: 1 << 4)  // 16
    static let statsLookup        	= DebugMode(rawValue: 1 << 5)  // 32
    static let navigation         	= DebugMode(rawValue: 1 << 6)  // 64
    static let caching            	= DebugMode(rawValue: 1 << 7)  // 128
    static let leagueProvider     	= DebugMode(rawValue: 1 << 8)  // 256
    static let viewModelLifecycle 	= DebugMode(rawValue: 1 << 9)  // 512
    static let dataSync           	= DebugMode(rawValue: 1 << 10)  // 1024
    static let nflData            	= DebugMode(rawValue: 1 << 11)  // 2048
    static let opponentIntel      	= DebugMode(rawValue: 1 << 12)  // 4096
    static let liveUpdates        	= DebugMode(rawValue: 1 << 13)  // 8192
    static let oprk               	= DebugMode(rawValue: 1 << 14)  // 16384
    static let lineupRX           	= DebugMode(rawValue: 1 << 15)  // 32768
    static let liveUpdate2 		  	= DebugMode(rawValue: 1 << 16)  // 65536
    static let waivers            	= DebugMode(rawValue: 1 << 17)  // 131072
    static let weekCheck          	= DebugMode(rawValue: 1 << 18)  // 262144, next free bit!

    // Convenience combinations
    static let allAPIs: DebugMode 	= [.espnAPI, .sleeperAPI]
    static let allData: DebugMode 	= [.statsLookup, .caching, .dataSync]
    static let all: DebugMode 		= [
        .globalRefresh,
        .espnAPI,
        .sleeperAPI,
        .matchupLoading,
        .recordCalculation,
        .statsLookup,
        .navigation,
        .caching,
        .leagueProvider,
        .viewModelLifecycle,
        .dataSync,
        .nflData,
        .opponentIntel,
        .liveUpdates,
        .oprk,
        .lineupRX,
		.liveUpdate2,
        .waivers,
        .weekCheck
    ]
}

// MARK: - Debug Configuration

enum DebugConfig {
    /// Change this to focus debug output on specific areas
    /// 
    /// Examples:
    /// - `.none` - No debug output (production)
    /// - `.all` - Everything (verbose)
    /// - `.globalRefresh` - Only global refresh logs
    /// - `[.espnAPI, .recordCalculation]` - Multiple specific areas
	///
	/// Current: Week checking and waiver wire debugging enabled
    static var activeMode: DebugMode = []

    /// Reset all iteration counters (useful for testing)
    static func resetIterations() {
        debugPrintIterations.removeAll()
    }
}

// MARK: - Iteration Tracking

/// Tracks how many times each debug statement has printed (by file:line)
private var debugPrintIterations: [String: Int] = [:]

// MARK: - Debug Print Function

/// Flexible debug print with mode filtering and iteration limiting
///
/// - Parameters:
///   - mode: Debug mode(s) to filter on. Defaults to .all if not specified
///   - limit: Maximum times this statement should print (0 = unlimited)
///   - file: Source file (auto-captured)
///   - line: Line number (auto-captured)
///   - function: Function name (auto-captured)
///   - message: Message to print (only evaluated if it will actually print)
///
/// Examples:
/// ```swift
/// // Single mode
/// DebugPrint(mode: .globalRefresh, "Starting refresh")
///
/// // Multiple modes
/// DebugPrint(mode: [.espnAPI, .sleeperAPI], "API response received")
///
/// // With iteration limit (only prints 5 times)
/// DebugPrint(mode: .statsLookup, limit: 5, "Checking stats for \(playerID)")
///
/// // Default to .all (prints if anything is active)
/// DebugPrint("General debug message")
/// ```
func DebugPrint(
    mode: DebugMode = .all,
    limit: Int = 0, // 0 = infinite
    file: String = #file,
    line: Int = #line,
    function: String = #function,
    _ message: @autoclosure () -> String
) {
    // Early exit if mode isn't active
    guard !DebugConfig.activeMode.intersection(mode).isEmpty else {
        return
    }
    
    // Handle iteration limiting
    if limit > 0 {
        let key = "\(file):\(line)"
        let count = debugPrintIterations[key, default: 0]
        
        // Already printed enough times?
        guard count < limit else { return }
        
        // Increment counter
        debugPrintIterations[key] = count + 1
        
        // Print with iteration info
        let fileName = (file as NSString).lastPathComponent
        let iterInfo = "[\(count + 1)/\(limit)]"
        print("🔍 \(iterInfo) [\(fileName):\(line)] \(function)")
        print("   \(message())")
    } else {
        // Unlimited printing
        let fileName = (file as NSString).lastPathComponent
        print("🔍 [\(fileName):\(line)] \(function)")
        print("   \(message())")
    }
}
