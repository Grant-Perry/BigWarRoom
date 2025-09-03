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
    
    /// Fetch leagues from both Sleeper and ESPN
    func fetchAllLeagues(sleeperUserID: String? = nil, season: String = "2025") async {
        await withTaskGroup(of: Void.self) { group in
            // Fetch Sleeper leagues if user ID provided
            if let userID = sleeperUserID {
                group.addTask { [weak self] in
                    await self?.fetchSleeperLeagues(userID: userID, season: season)
                }
            }
            
            // Fetch ESPN leagues
            group.addTask { [weak self] in
                await self?.fetchESPNLeagues()
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
    
    /// Fetch Sleeper leagues for a user
    private func fetchSleeperLeagues(userID: String, season: String = "2025") async {
        isLoadingSleeperLeagues = true
        defer { isLoadingSleeperLeagues = false }
        
        do {
            let leagues = try await sleeperClient.fetchLeagues(userID: userID, season: season)
            
            // Filter to only leagues with drafts
            let leaguesWithDrafts = leagues.filter { $0.draftID != nil }
            
            let sleeperWrappers = leaguesWithDrafts.map { league in
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
            
            print("✅ Fetched \(sleeperWrappers.count) Sleeper leagues for \(season) season")
            
        } catch {
            print("❌ Failed to fetch Sleeper leagues for \(season): \(error)")
        }
    }
    
    /// Fetch ESPN leagues
    func fetchESPNLeagues() async {
        isLoadingESPNLeagues = true
        defer { isLoadingESPNLeagues = false }
        
        print("🔍 Attempting to fetch ESPN leagues...")
        
        do {
            // FIXED: Use proper ESPN user ID and season
            let leagues = try await espnClient.fetchLeagues(
                userID: AppConstants.GpESPNID, 
                season: AppConstants.ESPNLeagueYear
            )
            
            print("🎯 ESPN client returned \(leagues.count) leagues")
            
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
            
            print("✅ Successfully fetched \(espnWrappers.count) ESPN leagues")
            
            // Log league details
            for wrapper in espnWrappers {
                print("  📊 ESPN: \(wrapper.league.name) (\(wrapper.league.totalRosters) teams) - Status: \(wrapper.league.status.displayName)")
            }
            
        } catch ESPNAPIError.authenticationFailed {
            print("🔐 ESPN authentication failed - cookies may be expired")
            print("💡 SWID: \(AppConstants.SWID)")
            print("💡 ESPN_S2 length: \(AppConstants.ESPN_S2.count) chars")
        } catch ESPNAPIError.decodingError(let error) {
            print("📄 ESPN data format error: \(error)")
        } catch {
            print("❌ Failed to fetch ESPN leagues: \(error)")
            print("🔍 Error type: \(type(of: error))")
            print("🔍 Error description: \(error.localizedDescription)")
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