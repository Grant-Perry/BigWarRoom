//
//  PlayerWatchService.swift
//  BigWarRoom
//
//  Service for managing the Player Watch system - real-time opponent monitoring
//

import Foundation
import SwiftUI
import Observation

/// **PlayerWatchService**
/// 
/// Manages watched players, notifications, and real-time score tracking
@Observable
@MainActor
final class PlayerWatchService {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: PlayerWatchService?
    
    static var shared: PlayerWatchService {
        if let existing = _shared {
            return existing
        }
        fatalError("PlayerWatchService.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: PlayerWatchService) {
        _shared = instance
    }
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    
    var watchedPlayers: [WatchedPlayer] = []
    var recentNotifications: [WatchNotification] = []
    var settings = WatchSettings()
    var isManuallyOrdered = false // Track if user has manually reordered
    var sortHighToLow = true // Track sort direction for threat mode
    var sortMethod: WatchSortMethod = .delta // Sort method with Delta as default
    
    // MARK: - Private Properties
    
    @ObservationIgnored private let userDefaults = UserDefaults.standard
    @ObservationIgnored private let maxWatchedPlayers = 25 // Increased from 10 to 25
    @ObservationIgnored private var notificationHistory: [String: Date] = [:] // Prevent spam
    @ObservationIgnored private let notificationCooldown: TimeInterval = 300 // 5 minutes between same-type notifications
    @ObservationIgnored private var weekObservationTask: Task<Void, Never>?
    
    // Keys for UserDefaults persistence
    @ObservationIgnored private let watchedPlayersKey = "BigWarRoom_WatchedPlayers"
    @ObservationIgnored private let watchSettingsKey = "BigWarRoom_WatchSettings"
    @ObservationIgnored private let manualOrderKey = "BigWarRoom_WatchedPlayers_ManualOrder"
    @ObservationIgnored private let sortDirectionKey = "BigWarRoom_WatchedPlayers_SortDirection"
    @ObservationIgnored private let sortMethodKey = "BigWarRoom_WatchedPlayers_SortMethod" // Persist sort method
    
    // MARK: - Dependencies
    private let weekManager: WeekSelectionManager
    private weak var allLivePlayersViewModel: AllLivePlayersViewModel?
    private let gameDataService: NFLGameDataService  // 🔥 PHASE 4 DI: Add NFLGameDataService
    
    // MARK: - Initialization
    
    // 🔥 PHASE 4 DI: Updated initializer
    init(
        weekManager: WeekSelectionManager,
        gameDataService: NFLGameDataService,
        allLivePlayersViewModel: AllLivePlayersViewModel? = nil
    ) {
        self.weekManager = weekManager
        self.gameDataService = gameDataService
        self.allLivePlayersViewModel = allLivePlayersViewModel
        loadWatchedPlayers()
        loadSettings()
        setupWeekChangeObservation()
    }
    
    // MARK: - Week Change Handling
    
    private func setupWeekChangeObservation() {
        weekObservationTask = Task { [weak self] in
            var lastObservedWeek = await self?.weekManager.selectedWeek
            
            while !Task.isCancelled {
                guard let self = self else { break }
                
                let currentWeek = await self.weekManager.selectedWeek
                
                if let lastWeek = lastObservedWeek, currentWeek != lastWeek {
                    await self.handleWeekChange(currentWeek)
                }
                
                lastObservedWeek = currentWeek
                
                // Check every 2 seconds
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    private func handleWeekChange(_ newWeek: Int) async {
        guard !watchedPlayers.isEmpty else { return }
        
        // Option 1: Clear all watched players when week changes (clean slate)
        // This might be more user-friendly since historical watches are less relevant
        if settings.clearWatchedPlayersOnWeekChange {
            clearAllWatchedPlayers()
            return
        }
        
        // Option 2: Update scores for new week (keep existing watches but with new data)
        
        // 🔥 FIXED: Use injected dependency instead of .shared
        guard let allLiveVM = allLivePlayersViewModel else {
            print("📅 PlayerWatchService: AllLivePlayersViewModel not available - manual refresh required")
            return
        }
        
        await allLiveVM.loadAllPlayers() // This should load data for the current week
        
        // Update watched player scores with the new week's data
        let allOpponentPlayers = allLiveVM.allPlayers.compactMap { playerEntry in
            OpponentPlayer(
                id: UUID().uuidString,
                player: playerEntry.player,
                isStarter: playerEntry.isStarter,
                currentScore: playerEntry.currentScore,
                projectedScore: playerEntry.projectedScore,
                threatLevel: .moderate,
                matchupAdvantage: .neutral,
                percentageOfOpponentTotal: 0.0
            )
        }
        
        updateWatchedPlayerScores(allOpponentPlayers)
    }
    
    // MARK: - Public Interface
    
    /// Add a player to the watch list
    /// - Parameters:
    ///   - player: The opponent player to watch
    ///   - opponentReferences: List of opponents who own this player
    /// - Returns: Success boolean
    func watchPlayer(_ player: OpponentPlayer, opponentReferences: [OpponentReference]) -> Bool {
        // Check if already watching
        if isWatching(player.player.id) {
            return false
        }
        
        // Check watch limit
        if watchedPlayers.count >= maxWatchedPlayers {
            return false
        }
        
        let watchedPlayer = WatchedPlayer(
            id: "watch_\(player.player.id)_\(Date().timeIntervalSince1970)",
            playerID: player.player.id,
            playerName: player.playerName,
            position: player.position,
            team: player.team,
            watchStartTime: Date(),
            initialScore: player.currentScore,
            opponentReferences: opponentReferences
        )
        
        watchedPlayers.append(watchedPlayer)
        saveWatchedPlayers()
        
        return true
    }
    
    /// Remove a player from the watch list
    /// - Parameter playerID: The player ID to unwatch
    func unwatchPlayer(_ playerID: String) {
        watchedPlayers.removeAll { $0.playerID == playerID }
        saveWatchedPlayers()
    }
    
    /// Check if a player is being watched
    /// - Parameter playerID: The player ID to check
    /// - Returns: True if being watched
    func isWatching(_ playerID: String) -> Bool {
        return watchedPlayers.contains { $0.playerID == playerID }
    }
    
    /// Clear all watched players
    func clearAllWatchedPlayers() {
        watchedPlayers.removeAll()
        saveWatchedPlayers()
    }
    
    /// Reset delta for a specific watched player (set initialScore to currentScore)
    /// - Parameter playerID: The player ID to reset delta for
    func resetPlayerDelta(_ playerID: String) {
        guard let index = watchedPlayers.firstIndex(where: { $0.playerID == playerID }) else {
            return
        }
        
        let currentScore = watchedPlayers[index].currentScore
        
        // Create new WatchedPlayer with reset initialScore and updated timestamp
        let resetPlayer = WatchedPlayer(
            id: watchedPlayers[index].id,
            playerID: watchedPlayers[index].playerID,
            playerName: watchedPlayers[index].playerName,
            position: watchedPlayers[index].position,
            team: watchedPlayers[index].team,
            watchStartTime: Date(), // Reset watch time to now
            initialScore: currentScore, // Set baseline to current score
            opponentReferences: watchedPlayers[index].opponentReferences,
            currentScore: currentScore,
            isLive: watchedPlayers[index].isLive
        )
        
        watchedPlayers[index] = resetPlayer
        saveWatchedPlayers()
    }
    
    /// Reset deltas for ALL watched players (set initialScore to currentScore for all)
    func resetAllDeltas() {
        guard !watchedPlayers.isEmpty else { return }
        
        let currentTime = Date()
        
        // Reset all players' deltas
        for i in watchedPlayers.indices {
            let currentScore = watchedPlayers[i].currentScore
            
            watchedPlayers[i] = WatchedPlayer(
                id: watchedPlayers[i].id,
                playerID: watchedPlayers[i].playerID,
                playerName: watchedPlayers[i].playerName,
                position: watchedPlayers[i].position,
                team: watchedPlayers[i].team,
                watchStartTime: currentTime, // Reset watch time to now for all
                initialScore: currentScore, // Set baseline to current score for all
                opponentReferences: watchedPlayers[i].opponentReferences,
                currentScore: currentScore,
                isLive: watchedPlayers[i].isLive
            )
        }
        
        saveWatchedPlayers()
    }
    
    /// Update scores for all watched players
    /// - Parameter opponentPlayers: Current opponent players with updated scores
    func updateWatchedPlayerScores(_ opponentPlayers: [OpponentPlayer]) {
        var updated = false
        
        for i in watchedPlayers.indices {
            if let currentPlayer = opponentPlayers.first(where: { $0.player.id == watchedPlayers[i].playerID }) {
                let previousScore = watchedPlayers[i].currentScore
                watchedPlayers[i].currentScore = currentPlayer.currentScore
                // 🔥 PHASE 4 DI: Use method instead of computed property
                watchedPlayers[i].isLive = currentPlayer.player.isLive(gameDataService: gameDataService)
                
                // Check for notification triggers
                if previousScore != currentPlayer.currentScore {
                    checkForNotifications(watchedPlayers[i])
                    updated = true
                }
            }
        }
        
        if updated && !isManuallyOrdered {
            // Only auto-sort if user hasn't manually reordered
            applySorting()
        }
    }
    
    /// Get watch count for display
    var watchCount: Int {
        watchedPlayers.count
    }
    
    /// Get watched players sorted by threat level
    var sortedWatchedPlayers: [WatchedPlayer] {
        watchedPlayers.sorted { $0.weightedThreatScore > $1.weightedThreatScore }
    }
    
    /// Get critical threat players (15+ point delta)
    var criticalThreats: [WatchedPlayer] {
        watchedPlayers.filter { $0.currentThreatLevel == .critical }
    }
    
    /// Clean up watched players after games complete
    func cleanupCompletedGames() {
        let activePlayers = watchedPlayers.filter { $0.isLive }
        let removedCount = watchedPlayers.count - activePlayers.count
        
        if removedCount > 0 {
            watchedPlayers = activePlayers
            saveWatchedPlayers()
        }
    }
    
    /// Manually reorder watched players
    /// - Parameters:
    ///   - from: Source indices
    ///   - to: Destination index
    func moveWatchedPlayers(from: IndexSet, to: Int) {
        // Apply the move directly to the current display order
        watchedPlayers.move(fromOffsets: from, toOffset: to)
        
        // Mark as manually ordered to prevent auto-sorting
        isManuallyOrdered = true
        
        saveWatchedPlayers()
        saveManualOrderFlag()
    }
    
    /// Get watched players in current display order (for drag consistency)
    var displayOrderWatchedPlayers: [WatchedPlayer] {
        if isManuallyOrdered {
            return watchedPlayers // Return in user's manual order
        } else {
            return applySorting()
        }
    }
    
    /// Reset to automatic threat-based sorting
    func resetToAutomaticSorting() {
        isManuallyOrdered = false
        watchedPlayers = applySorting()
        saveWatchedPlayers()
        saveManualOrderFlag()
    }
    
    /// Toggle sort direction for automatic sorting
    func toggleSortDirection() {
        sortHighToLow.toggle()
        if !isManuallyOrdered {
            watchedPlayers = applySorting()
        }
        saveSortDirection()
    }
    
    /// Change sort method
    func setSortMethod(_ method: WatchSortMethod) {
        sortMethod = method
        if !isManuallyOrdered {
            watchedPlayers = applySorting()
        }
        saveSortMethod()
    }
    
    /// Apply current sorting method
    private func applySorting() -> [WatchedPlayer] {
        let sorted: [WatchedPlayer]
        
        switch sortMethod {
        case .delta:
            sorted = watchedPlayers.sorted { sortHighToLow ? $0.deltaScore > $1.deltaScore : $0.deltaScore < $1.deltaScore }
        case .threat:
            sorted = watchedPlayers.sorted { sortHighToLow ? $0.weightedThreatScore > $1.weightedThreatScore : $0.weightedThreatScore < $1.weightedThreatScore }
        case .current:
            sorted = watchedPlayers.sorted { sortHighToLow ? $0.currentScore > $1.currentScore : $0.currentScore < $1.currentScore }
        case .name:
            sorted = watchedPlayers.sorted { sortHighToLow ? $0.playerName > $1.playerName : $0.playerName < $1.playerName }
        case .position:
            sorted = watchedPlayers.sorted { sortHighToLow ? $0.position > $1.position : $0.position < $1.position }
        }
        
        return sorted
    }
    
    // MARK: - Notification System
    
    private func checkForNotifications(_ watchedPlayer: WatchedPlayer) {
        guard settings.enableNotifications else { return }
        
        let delta = watchedPlayer.deltaScore
        let adjustedThresholds = getAdjustedThresholds()
        
        var notificationType: WatchNotification.NotificationType?
        
        // Determine notification type based on delta
        if delta >= adjustedThresholds.explosive {
            notificationType = .explosive
        } else if delta >= adjustedThresholds.critical {
            notificationType = .critical
        } else if delta >= adjustedThresholds.significant {
            notificationType = .significant
        } else if delta >= adjustedThresholds.notable {
            notificationType = .notable
        }
        
        // Send notification if threshold met and not in cooldown
        if let type = notificationType {
            let cooldownKey = "\(watchedPlayer.playerID)_\(type.rawValue)"
            
            if let lastNotification = notificationHistory[cooldownKey],
               Date().timeIntervalSince(lastNotification) < notificationCooldown {
                return // Still in cooldown
            }
            
            sendNotification(for: watchedPlayer, type: type)
            notificationHistory[cooldownKey] = Date()
        }
    }
    
    private func getAdjustedThresholds() -> (notable: Double, significant: Double, critical: Double, explosive: Double) {
        let multiplier = settings.notificationSensitivity.thresholdMultiplier
        return (
            notable: WatchNotification.NotificationType.notable.threshold * multiplier,
            significant: WatchNotification.NotificationType.significant.threshold * multiplier,
            critical: WatchNotification.NotificationType.critical.threshold * multiplier,
            explosive: WatchNotification.NotificationType.explosive.threshold * multiplier
        )
    }
    
    private func sendNotification(for watchedPlayer: WatchedPlayer, type: WatchNotification.NotificationType) {
        let notification = WatchNotification(
            watchedPlayer: watchedPlayer,
            notificationType: type,
            timestamp: Date(),
            deltaAtNotification: watchedPlayer.deltaScore
        )
        
        recentNotifications.insert(notification, at: 0)
        
        // Keep only last 20 notifications
        if recentNotifications.count > 20 {
            recentNotifications = Array(recentNotifications.prefix(20))
        }
        
        // Trigger system notification if enabled
        triggerSystemNotification(notification)
    }
    
    private func triggerSystemNotification(_ notification: WatchNotification) {
        // TODO: Implement actual system notifications
        // For now, just haptic feedback
        if settings.enableVibration && notification.notificationType.priority.shouldVibrate {
            triggerHapticFeedback(for: notification.notificationType.priority)
        }
    }
    
    private func triggerHapticFeedback(for priority: WatchNotification.NotificationPriority) {
        switch priority {
        case .low, .medium:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        case .high:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        case .urgent:
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            impact.impactOccurred()
        }
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: WatchSettings) {
        settings = newSettings
        saveSettings()
    }
    
    // MARK: - Persistence

    // 🔥 CRITICAL FIX: Use local file storage instead of UserDefaults to prevent overflow
    private var watchedPlayersFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("PlayerWatch_WatchedPlayers.json")
    }
    
    private var watchSettingsFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("PlayerWatch_Settings.json")
    }
    
    private func saveWatchedPlayers() {
        do {
            let data = try JSONEncoder().encode(watchedPlayers)
            try data.write(to: watchedPlayersFileURL)
        } catch {
            print("❌ PlayerWatchService: Failed to save watched players: \(error)")
        }
    }
    
    private func loadWatchedPlayers() {
        // 🔥 MIGRATION: First check if we need to migrate from UserDefaults
        if let legacyData = userDefaults.data(forKey: watchedPlayersKey) {
            do {
                try legacyData.write(to: watchedPlayersFileURL)
                userDefaults.removeObject(forKey: watchedPlayersKey)
                print("📁 PlayerWatchService: Migrated watched players from UserDefaults to file")
            } catch {
                print("❌ PlayerWatchService: Failed to migrate watched players: \(error)")
            }
        }
        
        // Load from file
        if FileManager.default.fileExists(atPath: watchedPlayersFileURL.path) {
            do {
                let data = try Data(contentsOf: watchedPlayersFileURL)
                watchedPlayers = try JSONDecoder().decode([WatchedPlayer].self, from: data)
            } catch {
                print("❌ PlayerWatchService: Failed to load watched players: \(error)")
                watchedPlayers = []
            }
        }
        
        loadManualOrderFlag() // Load the manual order flag from UserDefaults (small data)
        loadSortDirection() // Load the sort direction from UserDefaults (small data)
        loadSortMethod() // Load the sort method from UserDefaults (small data)
    }
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: watchSettingsFileURL)
        } catch {
            print("❌ PlayerWatchService: Failed to save settings: \(error)")
        }
    }
    
    private func loadSettings() {
        // 🔥 MIGRATION: First check if we need to migrate from UserDefaults
        if let legacyData = userDefaults.data(forKey: watchSettingsKey) {
            do {
                try legacyData.write(to: watchSettingsFileURL)
                userDefaults.removeObject(forKey: watchSettingsKey)
                print("📁 PlayerWatchService: Migrated settings from UserDefaults to file")
            } catch {
                print("❌ PlayerWatchService: Failed to migrate settings: \(error)")
            }
        }
        
        // Load from file
        if FileManager.default.fileExists(atPath: watchSettingsFileURL.path) {
            do {
                let data = try Data(contentsOf: watchSettingsFileURL)
                settings = try JSONDecoder().decode(WatchSettings.self, from: data)
            } catch {
                print("❌ PlayerWatchService: Failed to load settings: \(error)")
                settings = WatchSettings() // Use default settings
            }
        }
    }
    
    private func saveManualOrderFlag() {
        userDefaults.set(isManuallyOrdered, forKey: manualOrderKey)
    }
    
    private func loadManualOrderFlag() {
        isManuallyOrdered = userDefaults.bool(forKey: manualOrderKey)
    }
    
    private func saveSortDirection() {
        userDefaults.set(sortHighToLow, forKey: sortDirectionKey)
    }
    
    private func loadSortDirection() {
        if let savedDirection = userDefaults.object(forKey: sortDirectionKey) as? Bool {
            sortHighToLow = savedDirection
        } else {
            // Default sort direction based on method
            switch sortMethod {
            case .delta, .threat, .current:
                sortHighToLow = true // High to Low for scores (biggest deltas first)
            case .name, .position:
                sortHighToLow = false // A to Z for text fields
            }
        }
    }
    
    // Sort method persistence
    private func saveSortMethod() {
        userDefaults.set(sortMethod.rawValue, forKey: sortMethodKey)
    }
    
    private func loadSortMethod() {
        if let methodString = userDefaults.string(forKey: sortMethodKey),
           let method = WatchSortMethod(rawValue: methodString) {
            sortMethod = method
        } else {
            sortMethod = .delta // Default to Delta sorting
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        weekObservationTask?.cancel()
    }

    // MARK: - Statistics
    
    func getWatchStatistics() -> WatchStatistics {
        let totalWatched = watchedPlayers.count
        let avgDuration = watchedPlayers.isEmpty ? 0 : watchedPlayers.reduce(0) { $0 + $1.watchDuration } / Double(watchedPlayers.count)
        
        // Find most watched position
        let positions = watchedPlayers.map { $0.position }
        let mostWatched: String
        if positions.isEmpty {
            mostWatched = "N/A"
        } else {
            let positionCounts = Dictionary(grouping: positions, by: { $0 })
                .mapValues { $0.count }
            mostWatched = positionCounts.max(by: { $0.value < $1.value })?.key ?? "N/A"
        }
        
        let biggestDelta = watchedPlayers.map { $0.deltaScore }.max() ?? 0.0
        
        return WatchStatistics(
            totalPlayersWatched: totalWatched,
            averageWatchDuration: avgDuration,
            mostWatchedPosition: mostWatched,
            biggestDeltaCaught: biggestDelta,
            totalNotificationsSent: recentNotifications.count,
            accuracyRate: 0.75 // TODO: Calculate based on actual threat realization
        )
    }
}

// MARK: - Helper Extensions

extension PlayerWatchService {
    /// Create opponent references from intelligence data
    static func createOpponentReferences(for player: OpponentPlayer, from intelligence: [OpponentIntelligence]) -> [OpponentReference] {
        return intelligence.compactMap { intel in
            if intel.players.contains(where: { $0.player.id == player.player.id }) {
                return OpponentReference(
                    id: intel.id,
                    opponentName: intel.opponentTeam?.ownerName ?? "Unknown",
                    leagueName: intel.leagueName,
                    leagueSource: intel.leagueSource.rawValue
                )
            }
            return nil
        }
    }
}

// MARK: - Watch Sort Methods

/// Sorting methods for watched players
enum WatchSortMethod: String, CaseIterable {
    case delta = "delta"
    case threat = "threat"
    case current = "current"  // This is the "Score" option
    case name = "name"
    case position = "position"
    
    var displayName: String {
        switch self {
        case .delta: return "Delta"
        case .threat: return "Threat"
        case .current: return "Score"  // From "Current" to "Score"
        case .name: return "Name"
        case .position: return "Position"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .delta: return "Score Change"
        case .threat: return "Threat Level"
        case .current: return "Current Score"  // Keep detailed description
        case .name: return "Player Name"
        case .position: return "Position"
        }
    }
}