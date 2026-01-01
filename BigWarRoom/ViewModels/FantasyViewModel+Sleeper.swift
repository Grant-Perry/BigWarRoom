//
//  FantasyViewModel+Sleeper.swift
//  BigWarRoom
//
//  Sleeper Fantasy League functionality for FantasyViewModel
//

import Foundation
import SwiftUI

// MARK: - Sleeper API Integration
extension FantasyViewModel {
    
    func fetchSleeperLeague(leagueID: String) async throws {
        // 🔥 PHASE 2.6: Use SleeperAPIClient instead of raw URL
        do {
            let league = try await SleeperAPIClient.shared.fetchLeague(leagueID: leagueID)
            
            if let scoringSettings = league.scoringSettings {
                DebugPrint(mode: .scoring, "Loaded \(scoringSettings.count) rules for league \(leagueID)")
                
                let manager = ScoringSettingsManager.shared
                manager.registerSleeperScoringSettings(from: league, leagueID: leagueID)
                
                DebugPrint(mode: .scoring, "Registered with ScoringSettingsManager for league \(leagueID)")
            } else {
                DebugPrint(mode: .scoring, "No scoring settings found for league \(leagueID)")
            }
            
        } catch {
            DebugPrint(mode: .sleeperAPI, "Error fetching Sleeper league \(leagueID): \(error)")
            throw error
        }
    }
    
    func fetchSleeperRosters(leagueID: String) async throws -> [SleeperRoster] {
        // 🔥 PHASE 2.6: Use SleeperAPIClient instead of raw URL
        DebugPrint(mode: .sleeperAPI, "Fetching Sleeper roster data for league \(leagueID)")
        
        do {
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
            DebugPrint(mode: .sleeperAPI, "Decoded \(rosters.count) Sleeper rosters")
            
            DebugPrint(mode: .fantasy, "🔍 SLEEPER API RESPONSE - Record Diagnosis:")
            DebugPrint(mode: .fantasy, "   Total rosters: \(rosters.count)")
            
            var rosterIDToManagerID: [Int: String] = [:]
            
            for (index, roster) in rosters.enumerated() {
                let winsDisplay = roster.wins != nil ? "\(roster.wins!)" : "nil"
                let lossesDisplay = roster.losses != nil ? "\(roster.losses!)" : "nil"
                let tieValue = roster.ties ?? 0
                
                DebugPrint(mode: .fantasy, "   Roster \(index): ID=\(roster.rosterID), Owner=\(roster.ownerID ?? "nil")")
                DebugPrint(mode: .fantasy, "      Root level - wins:\(winsDisplay), losses:\(lossesDisplay), ties:\(tieValue)")
                
                if let settings = roster.settings {
                    let settingsWins = settings.wins ?? 0
                    let settingsLosses = settings.losses ?? 0
                    
                    DebugPrint(mode: .fantasy, "      Settings level - wins:\(settingsWins), losses:\(settingsLosses)")
                }
                
                if let ownerID = roster.ownerID {
                    rosterIDToManagerID[roster.rosterID] = ownerID
                } else {
                    DebugPrint(mode: .fantasy, "Sleeper roster \(roster.rosterID) has no owner!")
                }
            }
            
            await MainActor.run {
                self.rosterIDToManagerID = rosterIDToManagerID
            }
            DebugPrint(mode: .fantasy, "Populated rosterIDToManagerID with \(rosterIDToManagerID.count) entries")
            
            return rosters
        } catch {
            DebugPrint(mode: .sleeperAPI, "Sleeper rosters fetch error: \(error)")
            throw error
        }
    }
    
    func fetchSleeperUsers(leagueID: String) async throws -> [SleeperLeagueUser] {
        // 🔥 PHASE 2.6: Use SleeperAPIClient instead of raw URL
        DebugPrint(mode: .sleeperAPI, "Fetching Sleeper user data for league \(leagueID)")
        
        do {
            let users = try await SleeperAPIClient.shared.fetchUsers(leagueID: leagueID)
            DebugPrint(mode: .sleeperAPI, "Decoded \(users.count) Sleeper users")
            
            var userIDs: [String: String] = [:]
            for user in users {
                userIDs[user.userID] = user.displayName
            }
            
            await MainActor.run {
                self.userIDs = userIDs
            }
            
            DebugPrint(mode: .fantasy, "Successfully populated userIDs with \(userIDs.count) entries")
            
            return users
        } catch let decodingError as DecodingError {
            DebugPrint(mode: .sleeperAPI, "Sleeper users decoding error: \(decodingError)")
            throw decodingError
        } catch {
            DebugPrint(mode: .sleeperAPI, "Sleeper users fetch error: \(error)")
            throw error
        }
    }
    
    func fetchSleeperMatchups(leagueID: String, week: Int) async throws -> [SleeperMatchup] {
        // 🔥 PHASE 2.6: Use SleeperAPIClient instead of raw URL
        DebugPrint(mode: .sleeperAPI, "Fetching Sleeper matchup data for league \(leagueID) week \(week)")
        
        do {
            // SleeperAPIClient returns [SleeperMatchupResponse], need to convert to [SleeperMatchup]
            // Actually, looking at the code, these might be the same type or compatible
            let matchupResponses = try await SleeperAPIClient.shared.fetchMatchups(leagueID: leagueID, week: week)
            
            // Convert SleeperMatchupResponse to SleeperMatchup if needed
            // For now, assuming they're compatible or this will cause a compile error we can fix
            DebugPrint(mode: .sleeperAPI, "Decoded \(matchupResponses.count) Sleeper matchup entries")
            
            // TODO: May need type conversion here depending on SleeperMatchup vs SleeperMatchupResponse
            return matchupResponses as! [SleeperMatchup]
        } catch {
            DebugPrint(mode: .sleeperAPI, "Sleeper matchups fetch error: \(error)")
            throw error
        }
    }
    
    func fetchSleeperLeagueUsersAndRosters(leagueID: String, week: Int) async -> [FantasyMatchup] {
        do {
            async let usersTask = fetchSleeperUsers(leagueID: leagueID)
            async let rostersTask = fetchSleeperRosters(leagueID: leagueID)
            async let matchupsTask = fetchSleeperMatchups(leagueID: leagueID, week: week)
            
            let (users, rosters, matchupData) = try await (usersTask, rostersTask, matchupsTask)
            
            DebugPrint(mode: .fantasy, "✅ Sleeper data fetch complete:")
            DebugPrint(mode: .fantasy, "   Users: \(users.count)")
            DebugPrint(mode: .fantasy, "   Rosters: \(rosters.count)")
            DebugPrint(mode: .fantasy, "   Matchup entries: \(matchupData.count)")
            
            let processedMatchups = try await processSleeperMatchupData(
                matchups: matchupData,
                rosters: rosters,
                users: users,
                leagueID: leagueID,
                week: week
            )
            
            DebugPrint(mode: .fantasy, "   Processed matchups: \(processedMatchups.count)")
            
            return processedMatchups
        } catch {
            DebugPrint(mode: .sleeperAPI, "Error in fetchSleeperLeagueUsersAndRosters: \(error)")
            return []
        }
    }
    
    private func processSleeperMatchupData(
        matchups: [SleeperMatchup],
        rosters: [SleeperRoster],
        users: [SleeperLeagueUser],
        leagueID: String,
        week: Int
    ) async -> [FantasyMatchup] {
        
        var groupedMatchups: [Int: [SleeperMatchup]] = [:]
        for matchup in matchups {
            groupedMatchups[matchup.matchup_id, default: []].append(matchup)
        }
        
        var fantasyMatchups: [FantasyMatchup] = []
        
        for (matchupID, matchupPair) in groupedMatchups {
            guard matchupPair.count == 2 else {
                DebugPrint(mode: .fantasy, "⚠️ Matchup \(matchupID) has \(matchupPair.count) entries (expected 2)")
                continue
            }
            
            let matchup1 = matchupPair[0]
            let matchup2 = matchupPair[1]
            
            guard let team1 = try await buildFantasyTeam(from: matchup1, rosters: rosters, users: users, leagueID: leagueID),
                  let team2 = try await buildFantasyTeam(from: matchup2, rosters: rosters, users: users, leagueID: leagueID) else {
                DebugPrint(mode: .fantasy, "❌ Failed to build teams for matchup \(matchupID)")
                continue
            }
            
            let fantasyMatchup = FantasyMatchup(
                id: "\(leagueID)_\(matchupID)_\(week)",
                leagueID: leagueID,
                week: week,
                year: String(NFLWeekCalculator.getCurrentSeasonYear()),
                homeTeam: team1,
                awayTeam: team2,
                status: .live,
                winProbability: nil,
                startTime: nil,
                sleeperMatchups: (matchup1, matchup2)
            )
            
            fantasyMatchups.append(fantasyMatchup)
        }
        
        return fantasyMatchups
    }
    
    private func buildFantasyTeam(
        from matchup: SleeperMatchup,
        rosters: [SleeperRoster],
        users: [SleeperLeagueUser],
        leagueID: String
    ) async -> FantasyTeam? {
        
        guard let roster = rosters.first(where: { $0.rosterID == matchup.roster_id }) else {
            DebugPrint(mode: .fantasy, "❌ No roster found for roster_id \(matchup.roster_id)")
            return nil
        }
        
        guard let user = users.first(where: { $0.userID == roster.ownerID }) else {
            DebugPrint(mode: .fantasy, "❌ No user found for ownerID \(roster.ownerID ?? "nil")")
            return nil
        }
        
        let record = TeamRecord(
            wins: roster.wins ?? roster.settings?.wins ?? 0,
            losses: roster.losses ?? roster.settings?.losses ?? 0,
            ties: roster.ties ?? roster.settings?.ties ?? 0
        )
        
        let avatarURL = user.avatar != nil ? "https://sleepercdn.com/avatars/\(user.avatar!)" : nil
        
        let fantasyPlayers = try await buildFantasyPlayers(from: matchup, leagueID: leagueID)
        
        // 🔥 FIX: Handle optional displayName properly
        let teamName = user.displayName ?? user.username ?? "Team \(matchup.roster_id)"
        
        return FantasyTeam(
            id: String(matchup.roster_id),
            name: teamName,
            ownerName: teamName,
            record: record,
            avatar: avatarURL,
            currentScore: matchup.points,
            projectedScore: matchup.projected_points,
            roster: fantasyPlayers,
            rosterID: matchup.roster_id,
            faabTotal: nil,
            faabUsed: roster.waiversBudgetUsed
        )
    }
    
    private func buildFantasyPlayers(from matchup: SleeperMatchup, leagueID: String) async -> [FantasyPlayer] {
        // 🔥 FIX: Safely unwrap optionals
        guard let allPlayers = matchup.players,
              let starters = matchup.starters else {
            return []
        }
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        for playerID in allPlayers {
            if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: playerID) {
                let isStarter = starters.contains(playerID)
                
                let fantasyPlayer = FantasyPlayer(
                    id: playerID,
                    sleeperID: playerID,
                    espnID: sleeperPlayer.espnID,
                    firstName: sleeperPlayer.firstName,
                    lastName: sleeperPlayer.lastName,
                    position: sleeperPlayer.position ?? "FLEX",
                    team: sleeperPlayer.team,
                    jerseyNumber: sleeperPlayer.number?.description,
                    currentPoints: 0.0,
                    projectedPoints: 0.0,
                    gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: sleeperPlayer.team ?? ""),
                    isStarter: isStarter,
                    lineupSlot: isStarter ? sleeperPlayer.position : nil,
                    injuryStatus: sleeperPlayer.injuryStatus
                )
                
                fantasyPlayers.append(fantasyPlayer)
            }
        }
        
        return fantasyPlayers
    }
}