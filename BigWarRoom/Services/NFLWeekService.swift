//
//  NFLWeekService.swift
//  BigWarRoom
//
//  Centralized service to fetch and share current NFL week across the app
//

import Foundation
import Combine

@MainActor
final class NFLWeekService: ObservableObject {
    
    static let shared = NFLWeekService()
    
    // MARK: -> Published Properties (Available to all ViewModels)
    @Published var currentWeek: Int = 1
    @Published var currentYear: String = "2024"
    @Published var seasonType: String = "regular" // "pre", "regular", "post"
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    
    // MARK: -> Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        // Start with reasonable defaults
        currentYear = String(Calendar.current.component(.year, from: Date()))
        
        // Fetch real data immediately
        Task {
            await fetchCurrentNFLWeek()
            setupPeriodicUpdates()
        }
    }
    
    // MARK: -> Public Methods
    
    /// Manually refresh NFL week data
    func refresh() async {
        await fetchCurrentNFLWeek()
    }
    
    /// Get current week with debug override (but still use REAL week by default)
    func getCurrentWeek(debugWeek: Int? = nil) -> Int {
        if let debugWeek = debugWeek, AppConstants.debug {
            // x// x Print("🏈 NFLWeekService: Using EXPLICIT debug week \(debugWeek)")
            return debugWeek
        }
        // ALWAYS return the real current week (even in debug mode unless explicitly overridden)
        return currentWeek
    }
    
    // MARK: -> Private Methods
    
    /// Fetch current NFL week from Sleeper API
    private func fetchCurrentNFLWeek() async {
        // x// x Print("🏈 NFLWeekService: Fetching current NFL week...")
        isLoading = true
        
        do {
            let nflState = try await SleeperAPIClient.shared.fetchNFLState()
            
            // Update published properties
            currentWeek = nflState.displayWeek
            currentYear = nflState.leagueSeason
            seasonType = nflState.seasonType
            lastUpdated = Date()
            
            // x// x Print("🏈 NFLWeekService: Updated to Week \(currentWeek), Year \(currentYear), Season Type: \(seasonType)")
            
        } catch {
            // x// x Print("❌ NFLWeekService: Error fetching NFL state: \(error)")
            // Keep existing values on error
        }
        
        isLoading = false
    }
    
    /// Setup periodic updates every 5 minutes
    private func setupPeriodicUpdates() {
        Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchCurrentNFLWeek()
                }
            }
            .store(in: &cancellables)
    }
}
