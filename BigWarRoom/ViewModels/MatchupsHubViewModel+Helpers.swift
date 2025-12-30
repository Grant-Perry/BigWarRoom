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
    
    /// Get current year as string
    internal func getCurrentYear() -> String {
        return String(Calendar.current.component(.year, from: Date()))
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