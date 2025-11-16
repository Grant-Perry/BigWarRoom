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
        // Skip optimization check for chopped leagues or eliminated matchups
        guard !matchup.isChoppedLeague, !matchup.isMyManagerEliminated else {
            lineupOptimizationStatus[matchup.id] = .optimized // Treat as "optimized" to show green
            return
        }
        
        // Skip if no team data
        guard matchup.myTeam != nil else {
            lineupOptimizationStatus[matchup.id] = .critical
            return
        }
        
        let week = getCurrentWeek()
        let year = getCurrentYear()
        
        do {
            // Create optimizer instance (view-owned, no singleton)
            let optimizer = LineupOptimizerService()
            
            // Run optimization
            let result = try await optimizer.optimizeLineup(
                for: matchup,
                week: week,
                year: year,
                scoringFormat: "ppr"
            )
            
            // Check waiver recommendations
            let waiverRecommendations = try await optimizer.getWaiverRecommendations(
                for: matchup,
                week: week,
                year: year,
                limit: 5,
                scoringFormat: "ppr"
            )
            
            // Determine status based on Gp.'s rules:
            // Red: Lineup changes needed OR active BYE players
            // Yellow: No lineup changes/byes, but waiver suggestions
            // Green: Fully optimized
            
            let hasLineupChanges = !result.changes.isEmpty
            let hasWaiverSuggestions = !waiverRecommendations.isEmpty
            
            let status: LineupRXStatus
            if hasLineupChanges {
                status = .critical  // Red: needs lineup changes
            } else if hasWaiverSuggestions {
                status = .warning   // Yellow: waiver suggestions available
            } else {
                status = .optimized // Green: fully optimized
            }
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: \(matchup.league.league.name) - Status: \(status) (changes: \(result.changes.count), waivers: \(waiverRecommendations.count))")
            
            lineupOptimizationStatus[matchup.id] = status
            
        } catch {
            DebugPrint(mode: .lineupRX, "❌ OPTIMIZER: Failed to check optimization for \(matchup.league.league.name) - \(error.localizedDescription)")
            // On error, assume critical
            lineupOptimizationStatus[matchup.id] = .critical
        }
    }
    
    /// Get optimization status for a matchup (cached)
    func getLineupRXStatus(for matchup: UnifiedMatchup) -> LineupRXStatus {
        return lineupOptimizationStatus[matchup.id] ?? .critical
    }
    
    /// Legacy compatibility: Check if lineup is fully optimized (green)
    func isLineupOptimized(for matchup: UnifiedMatchup) -> Bool {
        return getLineupRXStatus(for: matchup).isOptimized
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