//
//  UnifiedLeagueManager.swift
//  BigWarRoom
//
//  Unified manager for handling both Sleeper and ESPN leagues
//
// MARK: -> Unified League Manager

import Foundation
import Combine
import Observation

@Observable
@MainActor
final class UnifiedLeagueManager {
    var allLeagues: [LeagueWrapper] = []
    var isLoadingSleeperLeagues = false
    var isLoadingESPNLeagues = false
    
    // 🔥 PHASE 2 CORRECTED: Inject dependencies instead of using .shared
    private let sleeperClient: SleeperAPIClient
    private let espnClient: ESPNAPIClient
    private let espnCredentials: ESPNCredentialsManager
    
    // Dependencies injected via initializer (proper @Observable pattern)
    init(sleeperClient: SleeperAPIClient, 
         espnClient: ESPNAPIClient,
         espnCredentials: ESPNCredentialsManager) {
        self.sleeperClient = sleeperClient
        self.espnClient = espnClient
        self.espnCredentials = espnCredentials
    }
    
    // MARK: -> League Wrapper
    struct LeagueWrapper: Identifiable, Equatable {
        let id: String
        let league: SleeperLeague
        let source: LeagueSource
        let client: DraftAPIClient
        
        // MARK: - Equatable Implementation
        static func == (lhs: LeagueWrapper, rhs: LeagueWrapper) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.league.id == rhs.league.id &&
                   lhs.source == rhs.source
            // Note: We don't compare clients since they're protocol types
        }

        enum LeagueSource: String, CaseIterable {
            case sleeper = "Sleeper"
            case espn = "ESPN"
            
            var displayName: String { rawValue }
            var color: String {
                switch self {
                case .sleeper: return "blue"
                case .espn: return "red"
                }
            }
        }
    }
    
    // MARK: -> Fetch All Leagues
    
    /// Fetch leagues from both Sleeper and ESPN - with username resolution
    func fetchAllLeagues(sleeperUserID: String? = nil, season: String = "2025") async {
        DebugPrint(mode: .matchupLoading, "🔵 FETCH ALL LEAGUES: Starting...")
        DebugPrint(mode: .matchupLoading, "   sleeperUserID: '\(sleeperUserID ?? "nil")'")
        DebugPrint(mode: .matchupLoading, "   ESPN hasValidCredentials: \(espnCredentials.hasValidCredentials)")
        DebugPrint(mode: .matchupLoading, "   season: '\(season)'")
        
        await withTaskGroup(of: Void.self) { group in
            // Fetch Sleeper leagues if user identifier provided
            if let userIdentifier = sleeperUserID {
                DebugPrint(mode: .sleeperAPI, "🔵 FETCH ALL LEAGUES: Will fetch Sleeper leagues for '\(userIdentifier)'")
                group.addTask { [weak self] in
                    await self?.fetchSleeperLeaguesWithIdentifier(userIdentifier: userIdentifier, season: season)
                }
            } else {
                DebugPrint(mode: .sleeperAPI, "🔵 FETCH ALL LEAGUES: ⚠️ NO Sleeper userID provided - skipping Sleeper leagues!")
            }
            
            // Fetch ESPN leagues if credentials exist
            if espnCredentials.hasValidCredentials {
                DebugPrint(mode: .espnAPI, "🔵 FETCH ALL LEAGUES: Will fetch ESPN leagues")
                group.addTask { [weak self] in
                    await self?.fetchESPNLeagues()
                }
            } else {
                DebugPrint(mode: .espnAPI, "🔵 FETCH ALL LEAGUES: No ESPN credentials - skipping ESPN leagues")
            }
        }
        
        // Sort leagues: Sleeper first, then ESPN, then by name within each source
        allLeagues.sort { first, second in
            // First, sort by source: Sleeper before ESPN
            if first.source != second.source {
                return first.source == .sleeper
            }
            // Within the same source, sort by league name
            return first.league.name < second.league.name
        }
        
        let sleeperCount = allLeagues.filter { $0.source == .sleeper }.count
        let espnCount = allLeagues.filter { $0.source == .espn }.count
        DebugPrint(mode: .matchupLoading, "🔵 FETCH ALL LEAGUES: Complete. Total: \(allLeagues.count) (Sleeper: \(sleeperCount), ESPN: \(espnCount))")
    }
    
    /// 🔥 NEW: Fetch Sleeper leagues with username or userID resolution
    func fetchSleeperLeaguesWithIdentifier(userIdentifier: String, season: String = "2025") async {
        DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: Starting fetch for identifier '\(userIdentifier)', season '\(season)'")
        isLoadingSleeperLeagues = true
        defer { 
            isLoadingSleeperLeagues = false 
            DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: Fetch complete. Total Sleeper leagues: \(allLeagues.filter { $0.source == .sleeper }.count)")
        }
        
        do {
            // First, resolve the identifier to get the user and userID
            DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: Resolving user identifier...")
            let user = try await sleeperClient.fetchUser(username: userIdentifier)
            DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: Resolved to userID: \(user.userID)")
            
            // Now fetch leagues using the resolved user ID
            DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: Fetching leagues for userID \(user.userID)...")
            let leagues = try await sleeperClient.fetchLeagues(userID: user.userID, season: season)
            DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: Found \(leagues.count) leagues from API")
            
            // Show ALL leagues, not just ones with active drafts
            // Users might want to see completed leagues too
            let sleeperWrappers = leagues.map { league in
                LeagueWrapper(
                    id: "sleeper_\(league.id)",
                    league: league,
                    source: .sleeper,
                    client: sleeperClient
                )
            }
            
            // Remove old Sleeper leagues and add new ones
            let previousCount = allLeagues.filter { $0.source == .sleeper }.count
            allLeagues.removeAll { $0.source == .sleeper }
            allLeagues.append(contentsOf: sleeperWrappers)
            DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: Replaced \(previousCount) old leagues with \(sleeperWrappers.count) new leagues")
            
        } catch {
            DebugPrint(mode: .sleeperAPI, "🟣 SLEEPER LEAGUES: ❌ ERROR fetching leagues: \(error)")
        }
    }
    
    /// Fetch Sleeper leagues for a user ID (kept for backward compatibility)
    func fetchSleeperLeagues(userID: String, season: String = "2025") async {
        await fetchSleeperLeaguesWithIdentifier(userIdentifier: userID, season: season)
    }
    
    /// Fetch ESPN leagues
    func fetchESPNLeagues() async {
        isLoadingESPNLeagues = true
        defer { isLoadingESPNLeagues = false }
        
        // Use saved credentials instead of hardcoded ones
        guard let swid = espnCredentials.getSWID() else {
            return
        }
        
        do {
            // Use the saved credentials and selected year
            let leagues = try await espnClient.fetchLeagues(
                userID: swid, 
                season: AppConstants.ESPNLeagueYear
            )
            
            let espnWrappers = leagues.map { league in
                LeagueWrapper(
                    id: "espn_\(league.id)",
                    league: league,
                    source: .espn,
                    client: espnClient
                )
            }
            
            // Remove old ESPN leagues and add new ones
            allLeagues.removeAll { $0.source == .espn }
            allLeagues.append(contentsOf: espnWrappers)
            
        } catch {
            // Silent error handling
        }
    }
    
    /// Refresh all leagues
    func refreshAllLeagues(sleeperUserID: String? = nil, season: String = "2025") async {
        await fetchAllLeagues(sleeperUserID: sleeperUserID, season: season)
    }
    
    /// Check if any leagues are currently loading
    var isLoading: Bool {
        isLoadingSleeperLeagues || isLoadingESPNLeagues
    }
}

extension UnifiedLeagueManager.LeagueWrapper {
    /// CENTRALIZED chopped league detection for the entire app - ONE SOURCE OF TRUTH
    var isChoppedLeague: Bool {
        // Only Sleeper leagues can be chopped
        guard source == .sleeper else {
            return false
        }
        
        // 🔥 DIRECT ACCESS: Use the definitive SleeperLeagueSettings logic
        return league.settings?.isChoppedLeague ?? false
    }
}