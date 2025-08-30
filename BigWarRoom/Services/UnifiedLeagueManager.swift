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
    func fetchAllLeagues(sleeperUserID: String? = nil) async {
        await withTaskGroup(of: Void.self) { group in
            // Fetch Sleeper leagues if user ID provided
            if let userID = sleeperUserID {
                group.addTask { [weak self] in
                    await self?.fetchSleeperLeagues(userID: userID)
                }
            }
            
            // Fetch ESPN leagues
            group.addTask { [weak self] in
                await self?.fetchESPNLeagues()
            }
        }
        
        // Sort leagues by name
        allLeagues.sort { $0.league.name < $1.league.name }
    }
    
    /// Fetch Sleeper leagues for a user
    private func fetchSleeperLeagues(userID: String) async {
        isLoadingSleeperLeagues = true
        defer { isLoadingSleeperLeagues = false }
        
        do {
            let leagues = try await sleeperClient.fetchLeagues(userID: userID, season: "2024")
            
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
            
            print("✅ Fetched \(sleeperWrappers.count) Sleeper leagues")
            
        } catch {
            print("❌ Failed to fetch Sleeper leagues: \(error)")
        }
    }
    
    /// Fetch ESPN leagues
    func fetchESPNLeagues() async {
        isLoadingESPNLeagues = true
        defer { isLoadingESPNLeagues = false }
        
        print("🔍 Attempting to fetch ESPN leagues...")
        
        do {
            // ESPN requires known league IDs from AppConstants
            let leagues = try await espnClient.fetchLeagues(userID: "", season: AppConstants.ESPNLeagueYear)
            
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
                print("  📊 \(wrapper.league.name) (\(wrapper.league.totalRosters) teams) - Status: \(wrapper.league.status.displayName)")
            }
            
        } catch ESPNAPIError.authenticationFailed {
            print("🔐 ESPN authentication failed - cookies may be expired")
            print("💡 User can still connect to Sleeper leagues and manual drafts")
        } catch ESPNAPIError.decodingError(let error) {
            print("📄 ESPN data format error: \(error)")
            print("💡 ESPN may have changed their API structure")
        } catch {
            print("❌ Failed to fetch ESPN leagues: \(error)")
            print("💡 ESPN connection failed, but Sleeper and manual drafts still work")
        }
    }
    
    /// Refresh all leagues
    func refreshAllLeagues(sleeperUserID: String? = nil) async {
        await fetchAllLeagues(sleeperUserID: sleeperUserID)
    }
    
    /// Check if any leagues are currently loading
    var isLoading: Bool {
        isLoadingSleeperLeagues || isLoadingESPNLeagues
    }
}