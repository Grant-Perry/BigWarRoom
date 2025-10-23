//
//  PlayerWatchService.swift
//  BigWarRoom
//
//  Service for managing the Player Watch system - real-time opponent monitoring
//

import Foundation
import SwiftUI
import Combine

/// **PlayerWatchService**
/// 
/// Manages watched players, notifications, and real-time score tracking
@MainActor
final class PlayerWatchService: ObservableObject {
    static let shared = PlayerWatchService()
    
    // MARK: - Published Properties
    
    @Published var watchedPlayers: [WatchedPlayer] = []
    @Published var recentNotifications: [WatchNotification] = []
    @Published var settings = WatchSettings()
    @Published var isManuallyOrdered = false // Track if user has manually reordered
    @Published var sortHighToLow = true // Track sort direction for threat mode
    @Published var sortMethod: WatchSortMethod = .delta // Sort method with Delta as default
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let maxWatchedPlayers = 25 // Increased from 10 to 25
    private var notificationHistory: [String: Date] = [:] // Prevent spam
    private let notificationCooldown: TimeInterval = 300 // 5 minutes between same-type notifications
    private var weekSubscription: AnyCancellable?
    
    // Keys for UserDefaults persistence
    private let watchedPlayersKey = "BigWarRoom_WatchedPlayers"
    private let watchSettingsKey = "BigWarRoom_WatchSettings"
    private let manualOrderKey = "BigWarRoom_WatchedPlayers_ManualOrder"
    private let sortDirectionKey = "BigWarRoom_WatchedPlayers_SortDirection"
    private let sortMethodKey = "BigWarRoom_WatchedPlayers_SortMethod" // Persist sort method
    
    // MARK: - Initialization
    
    private init() {
        loadWatchedPlayers()
        loadSettings()
        setupWeekChangeSubscription()
    }
    
    // MARK: - Week Change Handling
    
    private func setupWeekChangeSubscription() {
        weekSubscription = WeekSelectionManager.shared.$selectedWeek
            .removeDuplicates()
            .sink { [weak self] newWeek in
                Task { @MainActor in
                    await self?.handleWeekChange(newWeek)
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
        
        // Get fresh data from AllLivePlayersViewModel for the new week
        let allLiveVM = AllLivePlayersViewModel.shared
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
                watchedPlayers[i].isLive = currentPlayer.player.isLive
                
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
    
    private func saveWatchedPlayers() {
        if let data = try? JSONEncoder().encode(watchedPlayers) {
            userDefaults.set(data, forKey: watchedPlayersKey)
        }
    }
    
    private func loadWatchedPlayers() {
        if let data = userDefaults.data(forKey: watchedPlayersKey),
           let players = try? JSONDecoder().decode([WatchedPlayer].self, from: data) {
            watchedPlayers = players
        }
        loadManualOrderFlag() // Load the manual order flag too
        loadSortDirection() // Load the sort direction too
        loadSortMethod() // Load the sort method too
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: watchSettingsKey)
        }
    }
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: watchSettingsKey),
           let loadedSettings = try? JSONDecoder().decode(WatchSettings.self, from: data) {
            settings = loadedSettings
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
        weekSubscription?.cancel()
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
                    opponentName: intel.opponentTeam.ownerName,
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