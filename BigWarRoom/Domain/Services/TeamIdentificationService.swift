//
//  TeamIdentificationService.swift
//  BigWarRoom
//
//  Phase 2: Service to consolidate team identification logic (DRY principle)
//  Eliminates ~200 lines of duplicate code from MatchupsHubViewModel and LeagueMatchupProvider
//

import Foundation

/// Service responsible for identifying the authenticated user's team in a league
/// Works for both Sleeper and ESPN leagues
@MainActor
final class TeamIdentificationService {
    
    // MARK: - Dependencies
    
    private let sleeperClient: SleeperAPIClient
    private let espnClient: ESPNAPIClient
    private let sleeperCredentials: SleeperCredentialsManager
    
    // MARK: - Initialization
    
    init(
        sleeperClient: SleeperAPIClient,
        espnClient: ESPNAPIClient,
        sleeperCredentials: SleeperCredentialsManager
    ) {
        self.sleeperClient = sleeperClient
        self.espnClient = espnClient
        self.sleeperCredentials = sleeperCredentials
    }
    
    // MARK: - Public Interface
    
    /// Identify the authenticated user's team ID in a league
    /// Works for both Sleeper and ESPN leagues
    func identifyMyTeamID(for league: UnifiedLeagueManager.LeagueWrapper) async -> String? {
        DebugPrint(mode: .winProb, "🔍 identifyMyTeamID() called for league: \(league.league.name)")
        
        switch league.source {
        case .sleeper:
            return await identifySleeperTeamID(league: league)
        case .espn:
            return await identifyESPNTeamID(league: league)
        }
    }
    
    // MARK: - Sleeper Team Identification
    
    /// Identify user's team in a Sleeper league
    private func identifySleeperTeamID(league: UnifiedLeagueManager.LeagueWrapper) async -> String? {
        guard let username = sleeperCredentials.getUserIdentifier() else {
            DebugPrint(mode: .winProb, "   ❌ No Sleeper username")
            return nil
        }
        
        DebugPrint(mode: .winProb, "   Sleeper username: \(username)")
        
        // Resolve username to user ID
        let resolvedUserID: String
        do {
            if username.allSatisfy({ $0.isNumber }) {
                // Already a user ID
                resolvedUserID = username
            } else {
                // It's a username, resolve to user ID
                let user = try await sleeperClient.fetchUser(username: username)
                resolvedUserID = user.userID
            }
            DebugPrint(mode: .winProb, "   Resolved to user ID: \(resolvedUserID)")
        } catch {
            DebugPrint(mode: .winProb, "   ❌ Failed to resolve user ID: \(error)")
            return nil
        }
        
        // Fetch rosters and find user's team
        do {
            let rosters = try await sleeperClient.fetchRosters(leagueID: league.league.leagueID)
            
            if let userRoster = rosters.first(where: { $0.ownerID == resolvedUserID }) {
                let teamID = String(userRoster.rosterID)
                DebugPrint(mode: .winProb, "   ✅ Found my roster: ID=\(teamID)")
                return teamID
            } else {
                DebugPrint(mode: .winProb, "   ❌ My roster not found in league")
                return nil
            }
        } catch {
            DebugPrint(mode: .winProb, "   ❌ Failed to fetch rosters: \(error)")
            return nil
        }
    }
    
    // MARK: - ESPN Team Identification
    
    /// Identify user's team in an ESPN league
    private func identifyESPNTeamID(league: UnifiedLeagueManager.LeagueWrapper) async -> String? {
        let myESPNID = AppConstants.GpESPNID
        
        do {
            let espnLeague = try await espnClient.fetchESPNLeagueData(leagueID: league.league.leagueID)
            
            if let teams = espnLeague.teams {
                for team in teams {
                    if let owners = team.owners {
                        if owners.contains(myESPNID) {
                            let teamID = String(team.id)
                            DebugPrint(mode: .winProb, "   ✅ ESPN team ID: \(teamID)")
                            return teamID
                        }
                    }
                }
            }
            
            DebugPrint(mode: .winProb, "   ❌ ESPN team ID not found")
            return nil
        } catch {
            DebugPrint(mode: .winProb, "   ❌ Failed to fetch ESPN league data: \(error)")
            return nil
        }
    }
}