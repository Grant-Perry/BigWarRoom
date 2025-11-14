//
//  OpponentIntelligenceViewModel.swift
//  BigWarRoom
//
//  ViewModel for Opponent Intelligence Dashboard (OID)
//  🔥 PHASE 3 DI: Converted to use dependency injection
//

import Foundation
import SwiftUI
import Observation

/// **OpponentIntelligenceViewModel**
/// 
/// Manages opponent intelligence data and provides UI-ready analysis
@MainActor
@Observable
final class OpponentIntelligenceViewModel {
    
    // MARK: - Observable Properties
    
    var opponentIntelligence: [OpponentIntelligence] = []
    var allOpponentPlayers: [OpponentPlayer] = []
    var conflictPlayers: [ConflictPlayer] = []
    var strategicRecommendations: [StrategicRecommendation] = []
    var isLoading = false
    var isInjuryDataLoading = false // NEW: Specific injury loading state
    var lastUpdateTime = Date()
    var errorMessage: String?
    
    // MARK: - Filter & Sort Properties
    
    var selectedThreatLevel: ThreatLevel? = nil
    var selectedPosition: String = "All"
    var sortBy: SortMethod = .threatLevel
    var showConflictsOnly = false
    
    // MARK: - Analytics Properties
    
    var totalOpponentsTracked: Int = 0
    var criticalThreatCount: Int = 0
    var totalConflictCount: Int = 0
    var overallThreatAssessment: ThreatLevel = .low
    
    // MARK: - Dependencies (injected)
    
    private let intelligenceService = OpponentIntelligenceService.shared
    private let matchupsHubViewModel: MatchupsHubViewModel // 🔥 PHASE 3: Now injected
    private let allLivePlayersViewModel: AllLivePlayersViewModel // 🔥 PHASE 3: Now injected
    private var observationTask: Task<Void, Never>?
    
    // MARK: - Game Alerts Integration 🚨
    let gameAlertsManager = GameAlertsManager.shared

    // MARK: - Computed Properties
    
    /// Filtered and sorted opponent intelligence based on current settings
    var filteredIntelligence: [OpponentIntelligence] {
        var filtered = opponentIntelligence
        
        // Apply threat level filter
        if let threatFilter = selectedThreatLevel {
            filtered = filtered.filter { $0.threatLevel == threatFilter }
        }
        
        // Apply conflicts-only filter
        if showConflictsOnly {
            filtered = filtered.filter { !$0.conflictPlayers.isEmpty }
        }
        
        // Apply sorting
        switch sortBy {
        case .threatLevel:
            filtered.sort { $0.threatLevel.rawValue < $1.threatLevel.rawValue }
        case .scoreDifferential:
            filtered.sort { $0.scoreDifferential < $1.scoreDifferential }
        case .opponentScore:
            filtered.sort { $0.totalOpponentScore > $1.totalOpponentScore }
        case .leagueName:
            filtered.sort { $0.leagueName < $1.leagueName }
        }
        
        return filtered
    }
    
    /// All opponent players filtered by position
    var filteredOpponentPlayers: [OpponentPlayer] {
        let players = selectedPosition == "All" 
            ? allOpponentPlayers 
            : allOpponentPlayers.filter { $0.position.uppercased() == selectedPosition.uppercased() }
        
        return players.sorted { $0.currentScore > $1.currentScore }
    }
    
    /// High priority recommendations for quick attention
    var priorityRecommendations: [StrategicRecommendation] {
        strategicRecommendations.filter { $0.priority == .critical || $0.priority == .high }
    }
    
    /// Injury alerts only (separated from other recommendations)
    var injuryAlerts: [StrategicRecommendation] {
        strategicRecommendations.filter { $0.type == .injuryAlert }
            .sorted { recommendation1, recommendation2 in
                // Sort by priority first, then by injury status priority
                if recommendation1.priority.rawValue != recommendation2.priority.rawValue {
                    return recommendation1.priority.rawValue < recommendation2.priority.rawValue
                }
                
                // Extract injury status for sorting
                let status1 = recommendation1.injuryAlert?.injuryStatus.priorityRanking ?? 999
                let status2 = recommendation2.injuryAlert?.injuryStatus.priorityRanking ?? 999
                return status1 < status2
            }
    }
    
    /// Non-injury strategic recommendations (threat alerts, conflicts, opportunities)
    var nonInjuryRecommendations: [StrategicRecommendation] {
        strategicRecommendations.filter { $0.type != .injuryAlert }
            .filter { $0.priority == .critical || $0.priority == .high }
            .sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
    
    /// Available positions for filtering
    var availablePositions: [String] {
        let positions = Set(allOpponentPlayers.map { $0.position })
        return ["All"] + positions.sorted()
    }
    
    // MARK: - Initialization
    
    // 🔥 PHASE 3 DI: Dependency injection initializer
    init(matchupsHubViewModel: MatchupsHubViewModel, allLivePlayersViewModel: AllLivePlayersViewModel) {
        self.matchupsHubViewModel = matchupsHubViewModel
        self.allLivePlayersViewModel = allLivePlayersViewModel
        setupObservation()
        
        // NEW: Subscribe to injury loading state changes
        intelligenceService.onInjuryLoadingStateChanged = { [weak self] isLoading in
            Task { @MainActor in
                self?.isInjuryDataLoading = isLoading
            }
        }
    }
    
    deinit {
        Task { @MainActor in
            observationTask?.cancel()
        }
    }
    
    /// Setup @Observable observation to watch for matchups changes
    private func setupObservation() {
        observationTask = Task { @MainActor in
            var lastObservedMatchupsCount = 0
            
            while !Task.isCancelled {
                let currentMatchupsCount = matchupsHubViewModel.myMatchups.count
                
                if currentMatchupsCount != lastObservedMatchupsCount {
                    DebugPrint(mode: .opponentIntel, "Matchups changed from \(lastObservedMatchupsCount) to \(currentMatchupsCount)")
                    await refreshIntelligence()
                    lastObservedMatchupsCount = currentMatchupsCount
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Load opponent intelligence from current matchups
    func loadOpponentIntelligence() async {
        isLoading = true
        errorMessage = nil
        
        DebugPrint(mode: .opponentIntel, "Starting injury data loading...")
        isInjuryDataLoading = true // Start with injury loading true
        
        // Force a small delay to ensure the UI updates before we start processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        do {
            // Ensure matchups are loaded
            await matchupsHubViewModel.loadAllMatchups()
            
            DebugPrint(mode: .opponentIntel, "Analyzing opponents...")
            // Analyze opponents (this is fast)
            let intelligence = intelligenceService.analyzeOpponents(from: matchupsHubViewModel.myMatchups)
            
            DebugPrint(mode: .opponentIntel, "Generating recommendations (including injury scan)...")
            // Generate recommendations (this includes injury scanning - the slow part)
            let recommendations = intelligenceService.generateRecommendations(from: intelligence)
            
            DebugPrint(mode: .opponentIntel, "Updating UI with \(recommendations.filter { $0.type == .injuryAlert }.count) injury alerts...")
            // Update UI
            await updateIntelligenceData(intelligence: intelligence, recommendations: recommendations)
            
            DebugPrint(mode: .opponentIntel, "Injury data loading complete!")
            isInjuryDataLoading = false // Only set to false after recommendations are complete
            
        } catch {
            errorMessage = "Failed to load opponent intelligence: \(error.localizedDescription)"
            DebugPrint(mode: .opponentIntel, "Error during loading: \(error)")
            isInjuryDataLoading = false // Stop injury loading on error
        }
        
        isLoading = false
    }
    
    /// Refresh intelligence data (background refresh)
    func refreshIntelligence() async {
        DebugPrint(mode: .opponentIntel, "Background refresh - starting injury loading...")
        // Start injury loading for refresh
        isInjuryDataLoading = true
        
        // Small delay for UI update
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        let intelligence = intelligenceService.analyzeOpponents(from: matchupsHubViewModel.myMatchups)
        let recommendations = intelligenceService.generateRecommendations(from: intelligence)
        
        await updateIntelligenceData(intelligence: intelligence, recommendations: recommendations)
        
        DebugPrint(mode: .opponentIntel, "Background refresh complete - stopping injury loading")
        // Stop injury loading after refresh complete
        isInjuryDataLoading = false
    }
    
    /// Manual refresh trigger
    func manualRefresh() async {
        // 🔥 FIX: Clear cache immediately to force fresh injury scan
        DebugPrint(mode: .opponentIntel, "Manual refresh - clearing cache and starting injury loading...")
        intelligenceService.clearCache()
        
        isInjuryDataLoading = true // Show injury loading during manual refresh
        
        // Small delay for UI update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // 🔥 PHASE 3 DI: Use injected AllLivePlayersViewModel
        DebugPrint(mode: .opponentIntel, "Manual refresh - also refreshing AllLivePlayersViewModel")
        await allLivePlayersViewModel.refresh()
        
        // Now do the main intelligence refresh with fresh data
        await loadOpponentIntelligence()
    }
    
    /// Clear all cached data and force reload
    func clearCacheAndReload() async {
        intelligenceService.clearCache()
        await loadOpponentIntelligence()
    }
    
    /// Nuclear option: Clear ALL caches and force complete reload when week changes
    /// This ensures loading state stays true until ALL fresh data is ready
    func weekChangeReload() async {
        DebugPrint(mode: .opponentIntel, "Week change reload started")
        
        // Lock loading state - prevent any intermediate updates
        isLoading = true
        errorMessage = nil
        
        // Clear all local data immediately to prevent stale data showing
        opponentIntelligence = []
        allOpponentPlayers = []
        conflictPlayers = []
        strategicRecommendations = []
        
        do {
            // Clear intelligence cache IMMEDIATELY
            intelligenceService.clearCache()
            
            // 🔥 PHASE 3 DI: Use injected AllLivePlayersViewModel
            await allLivePlayersViewModel.refresh()
            
            // Force matchups hub to do a fresh load (not using cached data)
            DebugPrint(mode: .opponentIntel, "Forcing MatchupsHubViewModel refresh...")
            await matchupsHubViewModel.manualRefresh()
            
            // Reduced wait time since we're now more aggressive about cache clearing
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds instead of 0.5
            
            // Now analyze with truly fresh data
            DebugPrint(mode: .opponentIntel, "Analyzing opponents with fresh data...")
            let intelligence = intelligenceService.analyzeOpponents(from: matchupsHubViewModel.myMatchups)
            let recommendations = intelligenceService.generateRecommendations(from: intelligence)
            
            // Update UI with fresh data
            await updateIntelligenceData(intelligence: intelligence, recommendations: recommendations)
            
            DebugPrint(mode: .opponentIntel, "Week change reload completed successfully")
            
        } catch {
            errorMessage = "Failed to reload for new week: \(error.localizedDescription)"
            DebugPrint(mode: .opponentIntel, "Week change reload failed: \(error)")
        }
        
        // Only now set loading to false
        isLoading = false
    }
    
    // MARK: - Filter & Sort Methods
    
    func setThreatLevelFilter(_ threat: ThreatLevel?) {
        selectedThreatLevel = threat
    }
    
    func setPositionFilter(_ position: String) {
        selectedPosition = position
    }
    
    func setSortMethod(_ method: SortMethod) {
        sortBy = method
    }
    
    func toggleConflictsOnly() {
        showConflictsOnly.toggle()
    }
    
    // MARK: - Analytics Methods
    
    /// Get threat distribution for dashboard display
    func getThreatDistribution() -> [ThreatLevel: Int] {
        var distribution: [ThreatLevel: Int] = [:]
        
        for threat in ThreatLevel.allCases {
            distribution[threat] = opponentIntelligence.filter { $0.threatLevel == threat }.count
        }
        
        return distribution
    }
    
    /// Get top 3 most dangerous opponent players
    func getTopThreats() -> [OpponentPlayer] {
        return allOpponentPlayers
            .filter { $0.threatLevel == .explosive || $0.threatLevel == .dangerous }
            .sorted { $0.currentScore > $1.currentScore }
            .prefix(3)
            .map { $0 }
    }
    
    /// Get leagues where you're currently losing
    func getLosingMatchups() -> [OpponentIntelligence] {
        return opponentIntelligence.filter { $0.isLosingTo }
    }
    
    /// Get summary statistics for header display
    func getSummaryStats() -> (opponents: Int, threats: Int, conflicts: Int, losing: Int) {
        return (
            opponents: totalOpponentsTracked,
            threats: criticalThreatCount,
            conflicts: totalConflictCount,
            losing: getLosingMatchups().count
        )
    }
    
    // MARK: - Private Methods
    
    private func updateIntelligenceData(intelligence: [OpponentIntelligence], recommendations: [StrategicRecommendation]) async {
        // Update main data
        opponentIntelligence = intelligence
        strategicRecommendations = recommendations
        lastUpdateTime = Date()
        
        // Extract all opponent players
        allOpponentPlayers = intelligence.flatMap { $0.players }
        
        // Extract all conflicts
        conflictPlayers = intelligence.flatMap { $0.conflictPlayers }
        
        // Update analytics
        totalOpponentsTracked = intelligence.count
        criticalThreatCount = intelligence.filter { $0.threatLevel == .critical || $0.threatLevel == .high }.count
        totalConflictCount = conflictPlayers.count
        
        // Calculate overall threat assessment
        overallThreatAssessment = calculateOverallThreat(from: intelligence)
        
        DebugPrint(mode: .opponentIntel, "Updated with \(intelligence.count) opponents, \(conflictPlayers.count) conflicts, \(recommendations.count) recommendations")
    }
    
    private func calculateOverallThreat(from intelligence: [OpponentIntelligence]) -> ThreatLevel {
        guard !intelligence.isEmpty else { return .low }
        
        let threatCounts = intelligence.reduce(into: [ThreatLevel: Int]()) { counts, intel in
            counts[intel.threatLevel, default: 0] += 1
        }
        
        let total = intelligence.count
        let criticalPercentage = Double(threatCounts[.critical, default: 0]) / Double(total)
        let highPercentage = Double(threatCounts[.high, default: 0]) / Double(total)
        
        if criticalPercentage >= 0.3 { return .critical }
        if criticalPercentage + highPercentage >= 0.5 { return .high }
        if criticalPercentage + highPercentage >= 0.2 { return .medium }
        return .low
    }
    
    // MARK: - Helper Methods
    
    /// Format relative time for last update display
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Get SF Symbol for overall threat assessment
    func getOverallThreatSFSymbol() -> String {
        switch overallThreatAssessment {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "bolt.fill"
        case .low: return "checkmark.circle.fill"
        }
    }
    
    /// Get color for overall threat assessment
    func getOverallThreatColor() -> Color {
        overallThreatAssessment.color
    }
}

// MARK: - Enumerations

extension OpponentIntelligenceViewModel {
    enum SortMethod: String, CaseIterable, Identifiable {
        case threatLevel = "Threat Level"
        case scoreDifferential = "Score Difference"
        case opponentScore = "Opponent Score"
        case leagueName = "League Name"
        
        var id: String { rawValue }
    }
}