//
//  AllLivePlayersViewModel+StoreObservation.swift
//  BigWarRoom
//
//  🔥 REACTIVE STORE OBSERVATION: No more polling, pure reactivity
//

import Foundation
import SwiftUI

extension AllLivePlayersViewModel {
    
    /// 🔥 NEW: Start observing store changes (call this from view .onAppear)
    func startObservingStore() {
        DebugPrint(mode: .liveUpdates, "🎯 STORE OBSERVATION: Starting reactive observation of MatchupDataStore")
        // No task needed - SwiftUI's @Observable will automatically trigger updates
        // when matchupsHubViewModel.lastUpdateTime changes in the view
    }
    
    /// 🔥 NEW: Stop observing (call this from view .onDisappear if needed)
    func stopObservingStore() {
        DebugPrint(mode: .liveUpdates, "⏹️ STORE OBSERVATION: Stopping observation")
        // Nothing to clean up - SwiftUI handles observation lifecycle
    }
    
    /// 🔥 NEW: Handle store update (called when lastUpdateTime changes)
    func handleStoreUpdate() async {
        DebugPrint(mode: .liveUpdates, "🔄 STORE UPDATE: Detected change in MatchupDataStore")
        
        // Only process if we have initial data
        guard !allPlayers.isEmpty else {
            DebugPrint(mode: .liveUpdates, "⏭️ STORE UPDATE: Skipping - no initial data yet")
            return
        }
        
        // Get changed player IDs from store
        let changedIDs = matchupsHubViewModel.matchupDataStore.getChangedPlayers()
        
        if changedIDs.isEmpty {
            DebugPrint(mode: .liveUpdates, "⏭️ STORE UPDATE: No player changes detected")
            return
        }
        
        DebugPrint(mode: .liveUpdates, "🎯 STORE UPDATE: \(changedIDs.count) players changed - updating UI")
        
        // Perform delta update
        await performDeltaUpdate(changedPlayerIDs: changedIDs)
        
        lastUpdateTime = Date()
    }
    
    /// 🔥 NEW: Perform delta update (only changed players)
    private func performDeltaUpdate(changedPlayerIDs: Set<String>) async {
        isUpdating = true
        
        // Get fresh matchup data
        let freshMatchups = matchupsHubViewModel.myMatchups
        
        guard !freshMatchups.isEmpty else {
            isUpdating = false
            return
        }
        
        // Update only changed players
        var updatedPlayers = allPlayers
        
        for (index, entry) in allPlayers.enumerated() {
            // Skip if this player didn't change
            guard changedPlayerIDs.contains(entry.player.id) else {
                continue
            }
            
            // Find this player in fresh data
            if let freshMatchup = freshMatchups.first(where: { $0.id == entry.matchup.id }),
               let freshTeam = (freshMatchup.myTeam?.roster ?? []).first(where: { $0.id == entry.player.id }) ??
                              (freshMatchup.opponentTeam?.roster ?? []).first(where: { $0.id == entry.player.id }) {
                
                // Calculate delta
                let previousScore = entry.currentScore
                let newScore = freshTeam.currentPoints ?? 0.0
                let delta = newScore - previousScore
                
                // Create updated entry with new data
                let updatedEntry = LivePlayerEntry(
                    id: entry.id,
                    player: freshTeam,
                    leagueName: entry.leagueName,
                    leagueSource: entry.leagueSource,
                    currentScore: newScore,
                    projectedScore: freshTeam.projectedPoints ?? 0.0,
                    isStarter: freshTeam.isStarter,
                    percentageOfTop: entry.percentageOfTop, // Recalculate after
                    matchup: freshMatchup,
                    performanceTier: entry.performanceTier, // Recalculate after
                    lastActivityTime: delta > 0.01 ? Date() : entry.lastActivityTime,
                    previousScore: previousScore,
                    accumulatedDelta: entry.accumulatedDelta + delta
                )
                
                updatedPlayers[index] = updatedEntry
                
                DebugPrint(mode: .liveUpdates, limit: 5, "🎯 DELTA UPDATE: \(freshTeam.fullName) - \(previousScore) → \(newScore) (Δ\(String(format: "%+.2f", delta)))")
            }
        }
        
        // Update state
        allPlayers = updatedPlayers
        
        // Recalculate filters (this will recalculate stats internally)
        applyPositionFilter()
        
        isUpdating = false
        
        DebugPrint(mode: .liveUpdates, "✅ DELTA UPDATE: Complete - \(changedPlayerIDs.count) players updated")
    }
}