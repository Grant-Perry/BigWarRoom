//
//  TeamRosterCoordinator.swift
//  BigWarRoom
//
//  🏈 TEAM ROSTER DATA COORDINATOR 🏈
//  Eliminates race conditions for NFL team roster loading
//  Ensures proper data dependency coordination between services
//  🔥 PHASE 3 DI: Converted from singleton to dependency injection
//

import Foundation

/// **TeamRosterCoordinator**
/// 
/// Coordinates data loading for NFL team rosters to eliminate race conditions.
/// Ensures all dependencies are properly loaded before roster data is accessed.
@MainActor
final class TeamRosterCoordinator {
    // 🔥 PHASE 3: Removed static shared singleton
    
    // MARK: - State Management
    var isLoadingStats = false
    var isLoadingRoster = false
    var statsReady = false
    var lastStatsLoadTime: Date?
    
    // MARK: - Dependencies (injected)
    internal let livePlayersViewModel: AllLivePlayersViewModel
    private let nflRosterService = NFLTeamRosterService.shared // ⚠️ Still using singleton for NFL service (not part of this refactor)
    
    // MARK: - Cache
    private var cachedRosters: [String: NFLTeamRoster] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // 🔥 PHASE 3: Dependency injection initializer
    init(livePlayersViewModel: AllLivePlayersViewModel) {
        self.livePlayersViewModel = livePlayersViewModel
    }
    
    // MARK: - Public Interface
    
    /// Load team roster with proper data coordination
    /// This method ensures all dependencies are loaded before returning roster data
    func loadTeamRoster(for teamCode: String) async throws -> NFLTeamRoster {
        
        // Step 1: Ensure stats are loaded (critical for player points)
        try await ensureStatsAreLoaded()
        
        // Step 2: Ensure player directory is fresh
        try await ensurePlayerDirectoryIsReady()
        
        // Step 3: Check cache first
        if let cachedRoster = getCachedRoster(for: teamCode) {
            return cachedRoster
        }
        
        // Step 4: Load fresh roster data
        return try await loadFreshRoster(for: teamCode)
    }
    
    /// Check if we're ready to load rosters (all deps satisfied)
    var isReadyForRosterLoading: Bool {
        return statsReady && !isLoadingStats && !nflRosterService.needsRefresh
    }
    
    /// Force refresh all dependencies
    func forceRefresh() async {
        
        // Clear cache
        cachedRosters.removeAll()
        cacheTimestamps.removeAll()
        
        // Reset state
        statsReady = false
        lastStatsLoadTime = nil
        
        // Force reload dependencies
        await livePlayersViewModel.forceLoadStats()
        await nflRosterService.refreshPlayerDirectory()
        
        try? await ensureStatsAreLoaded()
    }
    
    // MARK: - Private Methods
    
    /// Ensure stats are loaded and ready
    private func ensureStatsAreLoaded() async throws {
        // If stats were loaded recently, we're good
        if let lastLoad = lastStatsLoadTime,
           Date().timeIntervalSince(lastLoad) < 60 { // 1 minute tolerance
            return
        }
        
        guard !isLoadingStats else {
            // Wait for existing load to complete
            while isLoadingStats {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            return
        }
        
        isLoadingStats = true
        defer { isLoadingStats = false }
        
        do {
            // Load stats if not already loaded
            if !livePlayersViewModel.statsLoaded {
                await livePlayersViewModel.loadAllPlayers()
            }
            
            // Verify stats are actually loaded
            let maxWaitTime: TimeInterval = 10 // 10 seconds max wait
            let startTime = Date()
            
            while !livePlayersViewModel.statsLoaded {
                if Date().timeIntervalSince(startTime) > maxWaitTime {
                    throw TeamRosterCoordinatorError.statsLoadTimeout
                }
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            
            statsReady = true
            lastStatsLoadTime = Date()
            
        } catch {
            throw error
        }
    }
    
    /// Ensure player directory is ready
    private func ensurePlayerDirectoryIsReady() async throws {
        if nflRosterService.needsRefresh {
            await nflRosterService.refreshPlayerDirectory()
        }
    }
    
    /// Get cached roster if valid
    private func getCachedRoster(for teamCode: String) -> NFLTeamRoster? {
        guard let roster = cachedRosters[teamCode.uppercased()],
              let timestamp = cacheTimestamps[teamCode.uppercased()],
              Date().timeIntervalSince(timestamp) < cacheTimeout else {
            return nil
        }
        return roster
    }
    
    /// Load fresh roster and cache it
    private func loadFreshRoster(for teamCode: String) async throws -> NFLTeamRoster {
        guard !isLoadingRoster else {
            // Wait for existing load
            while isLoadingRoster {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            
            // Try cache again after waiting
            if let cachedRoster = getCachedRoster(for: teamCode) {
                return cachedRoster
            }
            
            throw TeamRosterCoordinatorError.concurrentLoadError
        }
        
        isLoadingRoster = true
        defer { isLoadingRoster = false }
        
        do {
            let roster = nflRosterService.getTeamRoster(for: teamCode)
            
            // Cache the result
            cachedRosters[teamCode.uppercased()] = roster
            cacheTimestamps[teamCode.uppercased()] = Date()
            
            return roster
            
        } catch {
            throw error
        }
    }
    
    /// Get loading state description for debugging
    var loadingStateDescription: String {
        var states: [String] = []
        
        if isLoadingStats { states.append("Loading Stats") }
        if isLoadingRoster { states.append("Loading Roster") }
        if !statsReady { states.append("Stats Not Ready") }
        if nflRosterService.needsRefresh { states.append("Directory Needs Refresh") }
        
        return states.isEmpty ? "Ready" : states.joined(separator: ", ")
    }
}

// MARK: - Errors

enum TeamRosterCoordinatorError: Error, LocalizedError {
    case statsLoadTimeout
    case concurrentLoadError
    case playerDirectoryNotReady
    
    var errorDescription: String? {
        switch self {
        case .statsLoadTimeout:
            return "Timeout waiting for player stats to load"
        case .concurrentLoadError:
            return "Concurrent roster loading error"
        case .playerDirectoryNotReady:
            return "Player directory is not ready"
        }
    }
}