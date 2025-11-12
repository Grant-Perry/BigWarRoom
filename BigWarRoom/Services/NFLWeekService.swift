//
//  NFLWeekService.swift
//  BigWarRoom
//
//  Centralized service to fetch and share current NFL week across the app
//

import Foundation
import Observation

@Observable
@MainActor
final class NFLWeekService {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: NFLWeekService?
    
    static var shared: NFLWeekService {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance with default SleeperAPIClient
        let instance = NFLWeekService(apiClient: SleeperAPIClient())
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: NFLWeekService) {
        _shared = instance
    }
    
    // MARK: -> Observable Properties (Available to all ViewModels)
    var currentWeek: Int
    var currentYear: String = "2024"
    var seasonType: String = "regular" // "pre", "regular", "post"
    var isLoading: Bool = false
    var lastUpdated: Date?
    
    // MARK: -> Private Properties - Use @ObservationIgnored for internal state
    @ObservationIgnored private let updateInterval: TimeInterval = 300 // 5 minutes
    @ObservationIgnored private var updateTimer: Timer?
    
    // Dependencies - inject instead of using .shared
    private let apiClient: SleeperAPIClient
    
    init(apiClient: SleeperAPIClient) {
        self.apiClient = apiClient
        
        // Start with accurate calculation based on current date
        currentYear = String(Calendar.current.component(.year, from: Date()))
        currentWeek = Self.calculateCurrentWeek()
        
//        print("🗓️ NFLWeekService: Initialized with calculated week \(currentWeek), will verify with API...")
        
        // Fetch real data immediately to verify/correct
        Task {
            await fetchCurrentNFLWeek()
            setupPeriodicUpdates()
        }
    }
    
    // MARK: -> Static Helper
    /// Calculate current NFL week based on calendar date
    /// NFL weeks run Thursday-Wednesday, with games typically starting Thursday
    /// 2024 NFL Season started Thursday, September 5, 2024
    private static func calculateCurrentWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        
        // 2024 NFL Season: Week 1 started Thursday, September 5, 2024
        // 2025 NFL Season: Week 1 starts Thursday, September 4, 2025
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "America/New_York")
        
        // Determine season start based on year
        let seasonStartString: String
        if currentYear == 2024 {
            seasonStartString = "2024-09-05"  // Thursday, September 5, 2024
        } else if currentYear == 2025 {
            seasonStartString = "2025-09-04"  // Thursday, September 4, 2025
        } else {
            // For other years, assume first Thursday of September
            seasonStartString = "\(currentYear)-09-05"
        }
        
        guard let seasonStart = dateFormatter.date(from: seasonStartString) else {
            return 1
        }
        
        // Calculate weeks since season start
        let daysSinceStart = calendar.dateComponents([.day], from: seasonStart, to: now).day ?? 0
        
        // Get current day of week (1=Sunday, 3=Tuesday, 5=Thursday)
        let currentDayOfWeek = calendar.component(.weekday, from: now)
        
        // NFL "display week" logic:
        // - Week games are Thu-Mon
        // - On Tuesday, the "display week" advances to the NEXT week (for upcoming games)
        // - So on Tue/Wed, we show the upcoming week, not the week that just finished
        
        let weeksSinceStart = daysSinceStart / 7
        var calculatedWeek = weeksSinceStart + 1
        
        // If it's Tuesday (3) or Wednesday (4), advance to next week
        // This matches Sleeper's "displayWeek" logic
        if currentDayOfWeek == 3 || currentDayOfWeek == 4 {
            calculatedWeek += 1
        }
        
        // Cap at reasonable bounds (1-18)
        return min(18, max(1, calculatedWeek))
    }
    
    // MARK: -> Public Methods
    
    /// Manually refresh NFL week data
    func refresh() async {
        await fetchCurrentNFLWeek()
    }
    
    /// Get current week with debug override (but still use REAL week by default)
    func getCurrentWeek(debugWeek: Int? = nil) -> Int {
        if let debugWeek = debugWeek, AppConstants.debug {
            return debugWeek
        }
        // ALWAYS return the real current week (even in debug mode unless explicitly overridden)
        return currentWeek
    }
    
    // MARK: -> Private Methods
    
    /// Fetch current NFL week from Sleeper API
    private func fetchCurrentNFLWeek() async {
        isLoading = true
        
        do {
            let nflState = try await apiClient.fetchNFLState()
            
//            print("🗓️ NFLWeekService: API returned week \(nflState.displayWeek), season \(nflState.leagueSeason), type \(nflState.seasonType)")
            
            // Update properties - @Observable will automatically notify observers
            currentWeek = nflState.displayWeek
            currentYear = nflState.leagueSeason
            seasonType = nflState.seasonType
            lastUpdated = Date()
            
//            print("🗓️ NFLWeekService: Updated currentWeek to \(currentWeek)")
            
        } catch {
//            print("🗓️ NFLWeekService: Error fetching NFL state - \(error.localizedDescription)")
            // Keep existing values on error
        }
        
        isLoading = false
    }
    
    /// Setup periodic updates every 5 minutes
    private func setupPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchCurrentNFLWeek()
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
