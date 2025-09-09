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
    
    /// Fetch leagues from both Sleeper and ESPN
    func fetchAllLeagues(sleeperUserID: String? = nil, season: String = "2025") async {
        // x// x Print("🔍 UnifiedLeagueManager: fetchAllLeagues - Sleeper ID: \(sleeperUserID ?? "nil"), Season: \(season)")
        
        await withTaskGroup(of: Void.self) { group in
            // Fetch Sleeper leagues if user ID provided
            if let userID = sleeperUserID {
                group.addTask { [weak self] in
                    await self?.fetchSleeperLeagues(userID: userID, season: season)
                }
            }
            
            // Fetch ESPN leagues if credentials exist
            if espnCredentials.hasValidCredentials {
                group.addTask { [weak self] in
                    await self?.fetchESPNLeagues()
                }
            } else {
                // x// x Print("🚫 UnifiedLeagueManager: Skipping ESPN - no valid credentials")
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
        
        // x// x Print("✅ UnifiedLeagueManager: Final result - \(allLeagues.count) leagues total")
        for (index, wrapper) in allLeagues.enumerated() {
            // x// x Print("   \(index + 1). [\(wrapper.source.rawValue)] \(wrapper.league.name) - \(wrapper.league.totalRosters) teams")
        }
    }
    
    /// Fetch Sleeper leagues for a user
    func fetchSleeperLeagues(userID: String, season: String = "2025") async {
        isLoadingSleeperLeagues = true
        defer { isLoadingSleeperLeagues = false }
        
        // x// x Print("🔵 UnifiedLeagueManager: Fetching Sleeper leagues for user \(userID), season \(season)")
        
        do {
            let leagues = try await sleeperClient.fetchLeagues(userID: userID, season: season)
            // x// x Print("🔵 UnifiedLeagueManager: Sleeper API returned \(leagues.count) leagues")
            
            // Show ALL leagues, not just ones with active drafts
            // Users might want to see completed leagues too
            let sleeperWrappers = leagues.map { league in
                // x// x Print("   • Sleeper League: \(league.name) (Draft ID: \(league.draftID ?? "none"), Status: \(league.status.displayName))")
                return LeagueWrapper(
                    id: "sleeper_\(league.id)",
                    league: league,
                    source: .sleeper,
                    client: sleeperClient
                )
            }
            
            // Remove old Sleeper leagues and add new ones
            allLeagues.removeAll { $0.source == .sleeper }
            allLeagues.append(contentsOf: sleeperWrappers)
            
            // x// x Print("✅ UnifiedLeagueManager: Added \(sleeperWrappers.count) Sleeper leagues")
            
        } catch {
            // x// x Print("❌ UnifiedLeagueManager: Failed to fetch Sleeper leagues for \(season): \(error)")
        }
    }
    
    /// Fetch ESPN leagues
    func fetchESPNLeagues() async {
        isLoadingESPNLeagues = true
        defer { isLoadingESPNLeagues = false }
        
        // x// x Print("🔴 UnifiedLeagueManager: Fetching ESPN leagues...")
        
        // Use saved credentials instead of hardcoded ones
        guard let swid = espnCredentials.getSWID() else {
            // x// x Print("❌ UnifiedLeagueManager: No ESPN SWID available")
            return
        }
        
        do {
            // Use the saved credentials and selected year
            let leagues = try await espnClient.fetchLeagues(
                userID: swid, 
                season: AppConstants.ESPNLeagueYear
            )
            
            // x// x Print("🔴 UnifiedLeagueManager: ESPN API returned \(leagues.count) leagues")
            
            let espnWrappers = leagues.map { league in
                // x// x Print("   • ESPN League: \(league.name) (\(league.totalRosters) teams, Status: \(league.status.displayName))")
                return LeagueWrapper(
                    id: "espn_\(league.id)",
                    league: league,
                    source: .espn,
                    client: espnClient
                )
            }
            
            // Remove old ESPN leagues and add new ones
            allLeagues.removeAll { $0.source == .espn }
            allLeagues.append(contentsOf: espnWrappers)
            
            // x// x Print("✅ UnifiedLeagueManager: Added \(espnWrappers.count) ESPN leagues")
            
        } catch ESPNAPIError.authenticationFailed {
            // x// x Print("🔐 UnifiedLeagueManager: ESPN authentication failed - credentials may be expired")
            if let swid = espnCredentials.getSWID() {
                // x// x Print("💡 Using SWID: \(String(swid.prefix(20)))...")
            }
        } catch ESPNAPIError.decodingError(let error) {
            // x// x Print("📄 UnifiedLeagueManager: ESPN data format error: \(error)")
        } catch {
            // x// x Print("❌ UnifiedLeagueManager: Failed to fetch ESPN leagues: \(error)")
            // x// x Print("🔍 Error type: \(type(of: error))")
            // x// x Print("🔍 Error description: \(error.localizedDescription)")
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
        guard source == .sleeper,
              let sleeperLeague = league as? SleeperLeague else {
            return false
        }
        
        return SleeperLeagueSettings.isChoppedLeague(sleeperLeague)
    }
}
