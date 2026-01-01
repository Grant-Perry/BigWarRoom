import Foundation
import os.log

enum DebugConfig {
	  /// Change this to focus debug output on specific areas
	  ///
	  /// Examples:
	  /// - `.none` - No debug output (production)
	  /// - `.all` - Everything (verbose)
	  /// - `.globalRefresh` - Only global refresh logs
	  /// - `[.espnAPI, .recordCalculation]` - Multiple specific areas
	  ///
	  ///
	  ///  DO NOT DELETE:  the DebugMode is HERE ─────┐
	  ///                                           │
	  ///                         ┌──────────┘
	  ///                         ▼
   static var activeMode: DebugMode = [.matchupLoading] // [.liveUpdates, .matchupLoading] // .scoring // []

	  /// Reset all iteration counters (useful for testing)
   static func resetIterations() {
	  debugPrintIterations.removeAll()
   }
}

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
    static let weekCheck          	= DebugMode(rawValue: 1 << 18)  // 262144
    static let lifecycle          	= DebugMode(rawValue: 1 << 19)  // 524288
    static let general          	= DebugMode(rawValue: 1 << 20)  // 1048576
    static let scoring            	= DebugMode(rawValue: 1 << 21)  // 2097152
    static let fantasy            	= DebugMode(rawValue: 1 << 22)  // 4194304
    static let playerIDMapping    	= DebugMode(rawValue: 1 << 23)  // 8388608
    static let draft              	= DebugMode(rawValue: 1 << 24)  // 16777216
    static let contention         	= DebugMode(rawValue: 1 << 25)  // 33554432
    static let winProb            	= DebugMode(rawValue: 1 << 26)  // 67108864

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
        .weekCheck,
        .lifecycle,
        .general,
        .scoring,
        .fantasy,
        .playerIDMapping,
        .draft,
        .contention,
        .winProb
    ]
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
    
    let fileName = (file as NSString).lastPathComponent
    
    // Handle iteration limiting
    if limit > 0 {
        let key = "\(file):\(line)"
        let count = debugPrintIterations[key, default: 0]
        
        // Already printed enough times?
        guard count < limit else { return }
        
        // Increment counter
        debugPrintIterations[key] = count + 1
        
        // Print with iteration info
        let iterInfo = "[\(count + 1)/\(limit)]"
        NSLog("[\(fileName):\(line)] \(iterInfo) \(message())")
    } else {
        // Unlimited printing
        NSLog("[\(fileName):\(line)] \(message())")
    }
}
