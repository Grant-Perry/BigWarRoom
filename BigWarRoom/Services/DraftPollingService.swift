//
//  DraftPollingService.swift
//  BigWarRoom
//
//  Real-time draft polling service for live draft updates
//
// MARK: -> Draft Polling Service

import Foundation
import Combine
import UIKit

@MainActor
final class DraftPollingService: ObservableObject {
    static let shared = DraftPollingService()
    
    @Published private(set) var currentDraft: SleeperDraft?
    @Published private(set) var allPicks: [SleeperPick] = [] // Changed from recentPicks to allPicks
    @Published private(set) var recentPicks: [SleeperPick] = [] // Keep recent picks for other uses
    @Published private(set) var isPolling = false
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var error: Error?
    @Published private(set) var pollingCountdown: Double = 0.0
    @Published private(set) var currentPollingInterval: Double = 3.0
    
    private let apiClient = SleeperAPIClient.shared
    private let playerDirectory = PlayerDirectoryStore.shared
    
    private var pollingTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var pollInterval: TimeInterval = 3.0 // 3 seconds during active drafts
    private var lastPollTime: Date = Date()
    
    // MARK: -> Draft Polling
    
    /// Start polling a specific draft
    func startPolling(draftID: String) {
        stopPolling() // Stop any existing polling
        
        pollingTask = Task {
            await pollDraft(draftID: draftID)
        }
        
        // Start countdown timer
        startCountdownTimer()
    }
    
    /// Stop draft polling
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        countdownTask?.cancel()
        countdownTask = nil
        isPolling = false
        pollingCountdown = 0.0
    }
    
    /// Force an immediate refresh
    func forceRefresh() async {
        pollingCountdown = 0.0 // Reset countdown to trigger immediate poll
        print("🔄 Manual refresh triggered - resetting countdown")
    }
    
    /// Check if draft is currently active and worth polling
    var shouldPoll: Bool {
        // Poll if draft exists, regardless of status - let's see what's happening
        currentDraft != nil
    }
    
    // MARK: -> Private Polling Logic
    
    private func pollDraft(draftID: String) async {
        isPolling = true
        var lastPickCount = 0
        print("🔄 Starting polling for: \(draftID)")
        
        while !Task.isCancelled {
            lastPollTime = Date()
            
            do {
                let draft = try await apiClient.fetchDraft(draftID: draftID)
                currentDraft = draft
                
                let picks = try await apiClient.fetchDraftPicks(draftID: draftID)
                
                // Only log when there are new picks
                if picks.count > lastPickCount {
                    let newPicks = Array(picks.suffix(picks.count - lastPickCount))
                    print("🆕 \(newPicks.count) NEW PICKS DETECTED")
                    
                    await handleNewPicks(newPicks)
                    lastPickCount = picks.count
                }
                
                // Store ALL picks and recent subset
                allPicks = picks.sorted { $0.pickNo < $1.pickNo } // Store all picks sorted by pick number
                recentPicks = Array(picks.suffix(10)) // Keep last 10 for other uses
                
                print("📊 Polling update: \(allPicks.count) total picks, \(recentPicks.count) recent picks")
                
                // Adjust polling frequency based on draft status
                if draft.status == .drafting {
                    pollInterval = 2.0
                } else if picks.count > 0 {
                    pollInterval = 5.0
                } else {
                    pollInterval = 15.0
                }
                
                await MainActor.run {
                    currentPollingInterval = pollInterval
                }
                
                lastUpdate = Date()
                error = nil
                
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                
            } catch {
                print("❌ Polling error: \(error.localizedDescription)")
                self.error = error
                try? await Task.sleep(nanoseconds: UInt64(10 * 1_000_000_000))
            }
        }
        
        print("🛑 Polling stopped for: \(draftID)")
        isPolling = false
    }
    
    private func handleNewPicks(_ newPicks: [SleeperPick]) async {
        print("🏈 New picks detected: \(newPicks.count)")
        
        for pick in newPicks {
            if let playerID = pick.playerID,
               let player = playerDirectory.player(for: playerID) {
                print("📝 Pick \(pick.pickNo): \(player.shortName) (\(player.position ?? "")) to slot \(pick.draftSlot)")
            }
        }
        
        // Trigger haptic feedback for new picks
        triggerHapticForNewPicks()
    }
    
    private func triggerHapticForNewPicks() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
    }
    
    // MARK: -> Draft Analysis
    
    /// Get picks for a specific round
    func picks(for round: Int) -> [SleeperPick] {
        return allPicks.filter { $0.round == round } // Use allPicks instead of recentPicks
    }
    
    /// Get most recent pick
    var latestPick: SleeperPick? {
        return allPicks.last // Use allPicks instead of recentPicks
    }
    
    /// Convert Sleeper picks to internal Player models
    func convertToInternalPlayers(_ picks: [SleeperPick]) -> [Player] {
        return picks.compactMap { pick in
            guard let playerID = pick.playerID,
                  let sleeperPlayer = playerDirectory.player(for: playerID),
                  let internalPlayer = playerDirectory.convertToInternalPlayer(sleeperPlayer) else {
                return nil
            }
            return internalPlayer
        }
    }
    
    private func startCountdownTimer() {
        countdownTask = Task {
            while !Task.isCancelled && isPolling {
                let elapsed = Date().timeIntervalSince(lastPollTime)
                let remaining = max(0, currentPollingInterval - elapsed)
                
                await MainActor.run {
                    pollingCountdown = remaining
                }
                
                // Update every 0.1 seconds for smooth countdown
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    private init() {}
}

// MARK: -> Draft State Helpers
extension DraftPollingService {
    /// Is the draft currently in progress?
    var isDraftActive: Bool {
        currentDraft?.status == .drafting
    }
    
    /// Draft progress (picks made / total picks)
    var draftProgress: Double {
        guard let draft = currentDraft,
              let settings = draft.settings,
              let teams = settings.teams,
              let rounds = settings.rounds else {
            return 0.0
        }
        
        let totalPicks = teams * rounds
        let picksMade = allPicks.count // Use allPicks instead of recentPicks
        return Double(picksMade) / Double(totalPicks)
    }
    
    /// Current round being drafted
    var currentRound: Int? {
        guard let latestPick = latestPick else { return 1 }
        return latestPick.round
    }
}