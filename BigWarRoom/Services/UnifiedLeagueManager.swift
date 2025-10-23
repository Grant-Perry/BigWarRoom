//
//  UnifiedLeagueManager.swift
//  BigWarRoom
//
//  Unified manager for handling both Sleeper and ESPN leagues
//
// MARK: -> Unified League Manager

import Foundation
import Combine

@MainActor
final class UnifiedLeagueManager: ObservableObject {
    @Published var allLeagues: [LeagueWrapper] = []
    @Published var isLoadingSleeperLeagues = false
    @Published var isLoadingESPNLeagues = false
    
    private let sleeperClient = SleeperAPIClient.shared
    private let espnClient = ESPNAPIClient.shared
    private let espnCredentials = ESPNCredentialsManager.shared
    
    // MARK: -> League Wrapper
    struct LeagueWrapper: Identifiable {
        let id: String
        let league: SleeperLeague
        let source: LeagueSource
        let client: DraftAPIClient
        
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
        await withTaskGroup(of: Void.self) { group in
            // Fetch Sleeper leagues if user identifier provided
            if let userIdentifier = sleeperUserID {
                group.addTask { [weak self] in
                    await self?.fetchSleeperLeaguesWithIdentifier(userIdentifier: userIdentifier, season: season)
                }
            }
            
            // Fetch ESPN leagues if credentials exist
            if espnCredentials.hasValidCredentials {
                group.addTask { [weak self] in
                    await self?.fetchESPNLeagues()
                }
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
    }
    
    /// 🔥 NEW: Fetch Sleeper leagues with username or userID resolution
    func fetchSleeperLeaguesWithIdentifier(userIdentifier: String, season: String = "2025") async {
        isLoadingSleeperLeagues = true
        defer { isLoadingSleeperLeagues = false }
        
        do {
            // First, resolve the identifier to get the user and userID
            let user = try await sleeperClient.fetchUser(username: userIdentifier)
            
            // Now fetch leagues using the resolved user ID
            let leagues = try await sleeperClient.fetchLeagues(userID: user.userID, season: season)
            
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
            allLeagues.removeAll { $0.source == .sleeper }
            allLeagues.append(contentsOf: sleeperWrappers)
            
        } catch {
            // Silent error handling
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