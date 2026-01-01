//
//  MatchupsHubViewModel+Helpers.swift
//  BigWarRoom
//
//  Helper methods and utilities for MatchupsHubViewModel
//

import Foundation

// MARK: - Helper Methods
extension MatchupsHubViewModel {
    
    /// Get selected week (SSOT from WeekSelectionManager)
    /// This ensures refresh uses the user's selected week, not always current week
    internal func getCurrentWeek() -> Int {
        return WeekSelectionManager.shared.selectedWeek
    }
    
    /// Get current NFL season year (NOT calendar year)
    /// January 2026 = 2025 NFL season (since season started Sep 2025)
    internal func getCurrentYear() -> String {
        // Check if user manually set a season year in Settings
        if !AppConstants.ESPNLeagueYear.isEmpty {
            return AppConstants.ESPNLeagueYear
        }
        
        // Otherwise, calculate current NFL season
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        // NFL season logic:
        // September (9) through December (12) = Current calendar year's season
        // January (1) through August (8) = Previous calendar year's season
        if currentMonth >= 9 {
            return String(currentYear)
        } else {
            return String(currentYear - 1)
        }
    }
    
    // MARK: - 💊 RX Optimization Status Helpers
    
    /// Check if a lineup is optimized (no recommended changes)
    func checkLineupOptimization(for matchup: UnifiedMatchup) async {
        // Skip optimization check only for eliminated matchups
        // For Chopped leagues that are still alive, we *do* want to run LineupRX as a pure lineup optimizer
        guard !matchup.isMyManagerEliminated else {
            lineupOptimizationStatus[matchup.id] = true // Treat as "optimized" to show green
            return
        }
        
        // Skip if no team data
        guard matchup.myTeam != nil else {
            lineupOptimizationStatus[matchup.id] = false
            return
        }
        
        let week = getCurrentWeek()
        let year = getCurrentYear()
        
        do {
            // Create optimizer instance (view-owned, no singleton)
            let optimizer = LineupOptimizerService(gameDataService: gameDataService)
            
            // Run optimization
            let result = try await optimizer.optimizeLineup(
                for: matchup,
                week: week,
                year: year,
                scoringFormat: "ppr"
            )
            
            // Lineup is optimized if there are NO recommended changes
            let isOptimized = result.changes.isEmpty
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: \(matchup.league.league.name) - Optimized: \(isOptimized) (\(result.changes.count) changes)")
            
            lineupOptimizationStatus[matchup.id] = isOptimized
            
        } catch {
            DebugPrint(mode: .lineupRX, "❌ OPTIMIZER: Failed to check optimization for \(matchup.league.league.name) - \(error.localizedDescription)")
            // On error, assume not optimized
            lineupOptimizationStatus[matchup.id] = false
        }
    }
    
    /// Get optimization status for a matchup (cached)
    func isLineupOptimized(for matchup: UnifiedMatchup) -> Bool {
        return lineupOptimizationStatus[matchup.id] ?? false
    }
    
    /// Refresh optimization status for all matchups
    func refreshAllOptimizationStatuses() async {
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Refreshing optimization status for all matchups...")
        
        await withTaskGroup(of: Void.self) { group in
            for matchup in myMatchups {
                group.addTask {
                    await self.checkLineupOptimization(for: matchup)
                }
            }
        }
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Optimization status refresh complete")
    }
    
    /// Clear optimization status cache (called when week changes)
    func clearOptimizationStatusCache() {
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Clearing optimization status cache for week change")
        lineupOptimizationStatus.removeAll()
    }
}