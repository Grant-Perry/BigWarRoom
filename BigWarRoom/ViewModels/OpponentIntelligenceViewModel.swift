//
//  OpponentIntelligenceViewModel.swift
//  BigWarRoom
//
//  ViewModel for Opponent Intelligence Dashboard (OID)
//

import Foundation
import SwiftUI
import Combine

/// **OpponentIntelligenceViewModel**
/// 
/// Manages opponent intelligence data and provides UI-ready analysis
@MainActor
final class OpponentIntelligenceViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var opponentIntelligence: [OpponentIntelligence] = []
    @Published var allOpponentPlayers: [OpponentPlayer] = []
    @Published var conflictPlayers: [ConflictPlayer] = []
    @Published var strategicRecommendations: [StrategicRecommendation] = []
    @Published var isLoading = false
    @Published var lastUpdateTime = Date()
    @Published var errorMessage: String?
    
    // MARK: - Filter & Sort Properties
    
    @Published var selectedThreatLevel: ThreatLevel? = nil
    @Published var selectedPosition: String = "All"
    @Published var sortBy: SortMethod = .threatLevel
    @Published var showConflictsOnly = false
    
    // MARK: - Analytics Properties
    
    @Published var totalOpponentsTracked: Int = 0
    @Published var criticalThreatCount: Int = 0
    @Published var totalConflictCount: Int = 0
    @Published var overallThreatAssessment: ThreatLevel = .low
    
    // MARK: - Dependencies
    
    private let intelligenceService = OpponentIntelligenceService.shared
    private let matchupsHubViewModel = MatchupsHubViewModel()
    private var cancellables = Set<AnyCancellable>()
    
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
    
    /// Available positions for filtering
    var availablePositions: [String] {
        let positions = Set(allOpponentPlayers.map { $0.position })
        return ["All"] + positions.sorted()
    }
    
    // MARK: - Initialization
    
    init() {
        // Subscribe to MatchupsHubViewModel for real-time updates
        matchupsHubViewModel.$myMatchups
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshIntelligence()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    /// Load opponent intelligence from current matchups
    func loadOpponentIntelligence() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Ensure matchups are loaded
            await matchupsHubViewModel.loadAllMatchups()
            
            // Analyze opponents
            let intelligence = intelligenceService.analyzeOpponents(from: matchupsHubViewModel.myMatchups)
            
            // Generate recommendations
            let recommendations = intelligenceService.generateRecommendations(from: intelligence)
            
            // Update UI
            await updateIntelligenceData(intelligence: intelligence, recommendations: recommendations)
            
        } catch {
            errorMessage = "Failed to load opponent intelligence: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Refresh intelligence data (background refresh)
    func refreshIntelligence() async {
        // Don't show loading for background refresh
        let intelligence = intelligenceService.analyzeOpponents(from: matchupsHubViewModel.myMatchups)
        let recommendations = intelligenceService.generateRecommendations(from: intelligence)
        
        await updateIntelligenceData(intelligence: intelligence, recommendations: recommendations)
    }
    
    /// Manual refresh trigger
    func manualRefresh() async {
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
        print("🔄 OpponentIntelligenceViewModel: Week change reload started")
        
        // Lock loading state - prevent any intermediate updates
        isLoading = true
        errorMessage = nil
        
        // Clear all local data immediately to prevent stale data showing
        opponentIntelligence = []
        allOpponentPlayers = []
        conflictPlayers = []
        strategicRecommendations = []
        
        do {
            // Clear intelligence cache
            intelligenceService.clearCache()
            
            // Force matchups hub to do a fresh load (not using cached data)
            print("🔄 Forcing MatchupsHubViewModel refresh...")
            await matchupsHubViewModel.manualRefresh()
            
            // Wait a bit to ensure the refresh completed
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Now analyze with truly fresh data
            print("🔄 Analyzing opponents with fresh data...")
            let intelligence = intelligenceService.analyzeOpponents(from: matchupsHubViewModel.myMatchups)
            let recommendations = intelligenceService.generateRecommendations(from: intelligence)
            
            // Update UI with fresh data
            await updateIntelligenceData(intelligence: intelligence, recommendations: recommendations)
            
            print("🔄 Week change reload completed successfully")
            
        } catch {
            errorMessage = "Failed to reload for new week: \(error.localizedDescription)"
            print("❌ Week change reload failed: \(error)")
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
        
        print("🎯 OpponentIntelligenceViewModel: Updated with \(intelligence.count) opponents, \(conflictPlayers.count) conflicts, \(recommendations.count) recommendations")
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