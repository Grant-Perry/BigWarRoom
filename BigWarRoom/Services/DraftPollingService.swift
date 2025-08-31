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
    
    private let playerDirectory = PlayerDirectoryStore.shared
    
    private var pollingTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var pollInterval: TimeInterval = 3.0 // 3 seconds during active drafts
    private var lastPollTime: Date = Date()
    
    // API client - can be Sleeper or ESPN
    private var currentApiClient: DraftAPIClient? = nil
    
    // MARK: -> Draft Polling
    
    /// Set completed draft data without starting polling timer (for completed drafts)
    func setCompletedDraftData(draft: SleeperDraft, picks: [SleeperPick]) async {
        print("📋 Setting completed draft data: \(draft.status.rawValue) with \(picks.count) picks")
        
        currentDraft = draft
        allPicks = picks.sorted { $0.pickNo < $1.pickNo }
        recentPicks = Array(picks.suffix(10))
        lastUpdate = Date()
        error = nil
        isPolling = false // Explicitly set to false since we're not polling
        pollingCountdown = 0.0
        
        print("✅ Completed draft data loaded - no polling needed for \(draft.status.rawValue) draft")
    }
    
    /// Start polling a specific draft
    func startPolling(draftID: String, apiClient: DraftAPIClient? = nil) {
        stopPolling() // Stop any existing polling
        
        currentApiClient = apiClient ?? SleeperAPIClient.shared
        let clientType = currentApiClient is ESPNAPIClient ? "ESPN" : "Sleeper"
        print("🔄 Starting polling with \(clientType) API client for draftID: \(draftID)")
        
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
        
        guard let currentApiClient else {
            print("❌ No API client set")
            isPolling = false
            return
        }
        
        var lastPickCount = 0
        let clientType = currentApiClient is ESPNAPIClient ? "ESPN" : "Sleeper"
        print("🔄 Starting \(clientType) polling for draftID: \(draftID)")
        
        while !Task.isCancelled {
            lastPollTime = Date()
            
            do {
                print("📡 \(clientType) API - Fetching draft: \(draftID)")
                let draft = try await currentApiClient.fetchDraft(draftID: draftID)
                currentDraft = draft
                print("✅ \(clientType) - Draft fetched: \(draft.status.rawValue)")
                
                // SMART POLLING: Check if draft is still worth polling
                if draft.status != .drafting {
                    print("🚫 Draft status is \(draft.status.rawValue) - not live anymore")
                    
                    // Fetch final picks and stop polling
                    let picks = try await currentApiClient.fetchDraftPicks(draftID: draftID)
                    allPicks = picks.sorted { $0.pickNo < $1.pickNo }
                    recentPicks = Array(picks.suffix(10))
                    lastUpdate = Date()
                    
                    print("📋 Draft completed - fetched final \(picks.count) picks and stopping polling")
                    break // Exit polling loop
                }
                
                print("📡 \(clientType) API - Fetching draft picks...")
                let picks = try await currentApiClient.fetchDraftPicks(draftID: draftID)
                print("✅ \(clientType) - Fetched \(picks.count) draft picks")
                
                // Only log when there are new picks
                if picks.count > lastPickCount {
                    let newPicks = Array(picks.suffix(picks.count - lastPickCount))
                    print("🆕 \(clientType) - \(newPicks.count) NEW PICKS DETECTED")
                    
                    for (index, pick) in newPicks.enumerated() {
                        if let playerID = pick.playerID,
                           let player = PlayerDirectoryStore.shared.player(for: playerID) {
                            print("  \(index + 1). Pick \(pick.pickNo): \(player.shortName) (\(player.position ?? "")) to team \(pick.rosterID ?? -1)")
                        } else {
                            print("  \(index + 1). Pick \(pick.pickNo): Unknown player (ID: \(pick.playerID ?? "nil"))")
                        }
                    }
                    
                    await handleNewPicks(newPicks)
                    lastPickCount = picks.count
                } else if picks.count != lastPickCount {
                    print("📊 \(clientType) - Pick count changed from \(lastPickCount) to \(picks.count)")
                    lastPickCount = picks.count
                }
                
                // Store ALL picks and recent subset
                allPicks = picks.sorted { $0.pickNo < $1.pickNo } // Store all picks sorted by pick number
                recentPicks = Array(picks.suffix(10)) // Keep last 10 for other uses
                
                print("📊 \(clientType) polling update: \(allPicks.count) total picks, \(recentPicks.count) recent picks")
                
                // SMART POLLING INTERVALS: Adjust based on draft activity
                if draft.status == .drafting {
                    pollInterval = 3.0 // More frequent for live drafts
                    print("⚡ Live draft - polling every \(pollInterval)s")
                } else if picks.count > 0 {
                    pollInterval = 10.0 // Less frequent for completed drafts with picks
                    print("📋 Completed draft - polling every \(pollInterval)s")
                } else {
                    pollInterval = 30.0 // Very infrequent for empty drafts
                    print("⏰ Pre-draft - polling every \(pollInterval)s")
                }
                
                await MainActor.run {
                    currentPollingInterval = pollInterval
                }
                
                lastUpdate = Date()
                error = nil
                
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                
            } catch {
                print("❌ \(clientType) Polling error: \(error.localizedDescription)")
                if let espnError = error as? ESPNAPIError {
                    print("🔍 ESPN-specific error: \(espnError.errorDescription ?? "Unknown ESPN error")")
                }
                self.error = error
                
                // Longer delay on errors to avoid hammering failed endpoints
                try? await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000)) // 30 second delay on error
            }
        }
        
        print("🛑 \(clientType) polling stopped for: \(draftID)")
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