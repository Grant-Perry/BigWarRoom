//
//  FantasyViewModel+ESPN.swift
//  BigWarRoom
//
//  ESPN Fantasy League functionality for FantasyViewModel
//

import Foundation

// MARK: -> ESPN Fantasy Data Extension
extension FantasyViewModel {
    
    /// Fetch real ESPN fantasy data with proper authentication
    func fetchESPNFantasyData(leagueID: String, week: Int) async {
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&scoringPeriodId=\(week)") else {
            errorMessage = "Invalid ESPN API URL"
            return
        }
        
        // 🔥 FIX: First fetch the full league data with member info for name resolution AND scoring settings
        do {
            currentESPNLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: leagueID)
            print("✅ ESPN: Got league data with scoring settings for score breakdown")
            
            // 🔥 NEW: Debug the scoring settings to ensure they're available
            if let scoringSettings = currentESPNLeague?.scoringSettings {
                print("🔥 DEBUG: ESPN league has ROOT level scoring settings with \(scoringSettings.scoringItems?.count ?? 0) items")
            } else if let nestedScoring = currentESPNLeague?.settings?.scoringSettings {
                print("🔥 DEBUG: ESPN league has NESTED scoring settings with \(nestedScoring.scoringItems?.count ?? 0) items")
            } else {
                print("⚠️ DEBUG: ESPN league has NO scoring settings available for breakdown")
            }
            
        } catch {
            print("⚠️ ESPN: Failed to get league data, using fallback names - \(error)")
            currentESPNLeague = nil
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = AppConstants.currentESPNToken
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Handle events for debugging
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let schedule = json["schedule"] as? [[String: Any]] {
                
                let currentWeekEntries = schedule.filter { entry in
                    if let matchupPeriodId = entry["matchupPeriodId"] as? Int {
                        return matchupPeriodId == week
                    }
                    return false
                }
                
                // 🔍 FOCUSED DEBUG: Only show entries with missing/null away teams
                let problematicEntries = currentWeekEntries.filter { entry in
                    if let away = entry["away"] {
                        return away is NSNull
                    } else {
                        return true // missing away key
                    }
                }
                
                if !problematicEntries.isEmpty {
                    for (index, entry) in problematicEntries.enumerated() {
                        print("  Problem Entry \(index + 1): \(entry)")
                    }
                }
            }
            
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            NSLog("📊 ESPN \(leagueID): \(model.teams.count) teams, \(model.schedule.count) schedule")
            await processESPNFantasyData(espnModel: model, leagueID: leagueID, week: week)
            
        } catch {
            NSLog("❌ ESPN Decode Error for \(leagueID): \(error)")
            await tryAlternateTokenAsync(url: url, leagueID: leagueID, week: week)
        }
    }
    
    /// Try alternate ESPN token asynchronously
    private func tryAlternateTokenAsync(url: URL, leagueID: String, week: Int) async {
        let alternateToken = AppConstants.currentAlternateESPNToken
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(alternateToken)", forHTTPHeaderField: "Cookie")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            debugScheduleStructure(data: data, leagueID: leagueID)
        } catch {
            debugScheduleStructure(data: nil, leagueID: leagueID)
        }
    }
    
    /// Debug schedule structure for better visibility
    private func debugScheduleStructure(data: Data?, leagueID: String) {
        guard let data = data else {
            NSLog("❌ \(leagueID): No data received")
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("❌ \(leagueID): Could not parse JSON at all")
            return
        }
        
        NSLog("🔍 \(leagueID): Top-level keys: \(Array(json.keys).sorted())")
        
        guard let schedule = json["schedule"] as? [[String: Any]] else {
            NSLog("❌ \(leagueID): No schedule array found")
            return
        }
        
        NSLog("📊 \(leagueID): \(schedule.count) total schedule entries")
        
        let currentWeekEntries = schedule.filter { entry in
            if let matchupPeriodId = entry["matchupPeriodId"] as? Int {
                return matchupPeriodId == selectedWeek
            }
            return false
        }
        
        NSLog("🏈 \(leagueID): \(currentWeekEntries.count) entries for week \(selectedWeek)")
        
        for (index, entry) in currentWeekEntries.enumerated() {
            NSLog("🔍 \(leagueID): Schedule entry \(index + 1) keys: \(Array(entry.keys).sorted())")
            
            if let away = entry["away"] as? [String: Any] {
                NSLog("✅ \(leagueID): Entry \(index + 1) HAS 'away' key with: \(Array(away.keys).sorted())")
            } else {
                NSLog("❌ \(leagueID): Entry \(index + 1) MISSING 'away' key!")
            }
            
            if let home = entry["home"] as? [String: Any] {
                NSLog("✅ \(leagueID): Entry \(index + 1) HAS 'home' key with: \(Array(home.keys).sorted())")
            } else {
                NSLog("❌ \(leagueID): Entry \(index + 1) MISSING 'home' key!")
            }
        }
    }
    
    /// Process ESPN Fantasy data exactly like the working test view
    func processESPNFantasyData(espnModel: ESPNFantasyLeagueModel, leagueID: String, week: Int) async {
        // Store team records and names for later lookup
        for team in espnModel.teams {
            espnTeamNames[team.id] = team.name
            if let record = team.record?.overall {
                espnTeamRecords[team.id] = TeamRecord(
                    wins: record.wins,
                    losses: record.losses,
                    ties: record.ties
                )
            }
        }
        
        var processedMatchups: [FantasyMatchup] = []
        var byeTeams: [FantasyTeam] = []
        
        let weekSchedule = espnModel.schedule.filter { $0.matchupPeriodId == week }
        
        for scheduleEntry in weekSchedule {
            // Handle bye weeks
            guard let awayTeamEntry = scheduleEntry.away else {
                let homeTeamName = espnModel.teams.first { $0.id == scheduleEntry.home.teamId }?.name ?? "Unknown"
                
                // Convert this specific schedule entry back to JSON for inspection
                if let jsonData = try? JSONEncoder().encode(scheduleEntry),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("   \(jsonString)")
                }
                
                // Check if this team appears as an away team in any other matchup
                let appearsAsAway = weekSchedule.contains { otherEntry in
                    otherEntry.away?.teamId == scheduleEntry.home.teamId
                }
                
                if appearsAsAway {
                    print("⚠️ DUPLICATE: Team \(scheduleEntry.home.teamId) ALSO appears as away team in another entry!")
                }
                
                if let homeTeam = espnModel.teams.first(where: { $0.id == scheduleEntry.home.teamId }) {
                    let homeScore = homeTeam.activeRosterScore(for: week)
                    let byeTeam = createFantasyTeamFromESPN(
                        espnTeam: homeTeam,
                        score: homeScore,
                        leagueID: leagueID
                    )
                    byeTeams.append(byeTeam)
                }
                continue
            }
            
            let awayTeamId = awayTeamEntry.teamId
            let homeTeamId = scheduleEntry.home.teamId
            
            guard let awayTeam = espnModel.teams.first(where: { $0.id == awayTeamId }),
                  let homeTeam = espnModel.teams.first(where: { $0.id == homeTeamId }) else {
                continue
            }
            
            // Calculate real ESPN scores
            let awayScore = awayTeam.activeRosterScore(for: week)
            let homeScore = homeTeam.activeRosterScore(for: week)
            
            let awayFantasyTeam = createFantasyTeamFromESPN(
                espnTeam: awayTeam,
                score: awayScore,
                leagueID: leagueID
            )
            
            let homeFantasyTeam = createFantasyTeamFromESPN(
                espnTeam: homeTeam,
                score: homeScore,
                leagueID: leagueID
            )
            
            let matchup = FantasyMatchup(
                id: "\(leagueID)_\(week)_\(awayTeamId)_\(homeTeamId)",
                leagueID: leagueID,
                week: week,
                year: selectedYear,
                homeTeam: homeFantasyTeam,
                awayTeam: awayFantasyTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil
            )
            
            processedMatchups.append(matchup)
        }
        
        matchups = processedMatchups.sorted { $0.homeTeam.ownerName < $1.homeTeam.ownerName }
        byeWeekTeams = byeTeams
        
        // 🔥 NEW: Verify that currentESPNLeague is still populated after processing
        if currentESPNLeague != nil {
            print("✅ ESPN: currentESPNLeague is available for score breakdowns")
        } else {
            print("❌ ESPN: currentESPNLeague is unexpectedly nil after processing")
        }
    }

    /// Create FantasyTeam from ESPN data
    func createFantasyTeamFromESPN(espnTeam: ESPNFantasyTeamModel, score: Double, leagueID: String) -> FantasyTeam {
        var fantasyPlayers: [FantasyPlayer] = []
        
        if let roster = espnTeam.roster {
            fantasyPlayers = roster.entries.map { entry in
                let player = entry.playerPoolEntry.player
                let weeklyScore = player.stats.first { stat in
                    stat.scoringPeriodId == selectedWeek && stat.statSourceId == 0
                }?.appliedTotal ?? 0.0
                
                return FantasyPlayer(
                    id: String(player.id),
                    sleeperID: nil,
                    espnID: String(player.id),
                    firstName: player.fullName.firstName,
                    lastName: player.fullName.lastName,
                    position: positionString(entry.lineupSlotId),
                    team: player.nflTeamAbbreviation,
                    jerseyNumber: nil,
                    currentPoints: weeklyScore,
                    projectedPoints: weeklyScore * 1.1,
                    gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: player.nflTeamAbbreviation),
                    isStarter: [0, 2, 3, 4, 5, 6, 23, 16, 17].contains(entry.lineupSlotId),
                    lineupSlot: positionString(entry.lineupSlotId)
                )
            }
        }
        
        let record: TeamRecord?
        if let espnRecord = espnTeam.record?.overall {
            record = TeamRecord(
                wins: espnRecord.wins,
                losses: espnRecord.losses,
                ties: espnRecord.ties
            )
        } else {
            record = nil
        }
        
        // 🔥 FIX: Improved team name resolution with better fallbacks
        let realTeamName: String = {
            // Try to get manager name from ESPN league member data
            if let espnLeague = currentESPNLeague {
                // Find the ESPN team that matches this fantasy team
                if let espnTeamData = espnLeague.teams?.first(where: { $0.id == espnTeam.id }) {
                    let managerName = espnLeague.getManagerName(for: espnTeamData.owners)
                    
                    // 🔥 FIX: Don't use truncated fallback names like "Manager 28BB151}"
                    if !managerName.hasPrefix("Manager ") && managerName.count > 4 {
                        return managerName
                    }
                }
            }
            
            // Try the basic team name if it's not generic
            if let teamName = espnTeam.name, 
               !teamName.hasPrefix("Team ") && teamName.count > 4 {
                return teamName
            }
            
            // Last resort: use a clean team identifier
            return "ESPN Team \(espnTeam.id)"
        }()
        
        // Use the REAL team name for both team name and owner name
        return FantasyTeam(
            id: String(espnTeam.id),
            name: realTeamName, // Use real team name
            ownerName: realTeamName, // Use real team name as owner name
            record: record,
            avatar: nil,
            currentScore: score,
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: espnTeam.id
        )
    }
    
    /// Convert ESPN lineup slot ID to position string
    private func positionString(_ lineupSlotId: Int) -> String {
        switch lineupSlotId {
        case 0: return "QB"
        case 2, 3: return "RB" 
        case 4, 5: return "WR"
        case 6: return "TE"
        case 16: return "D/ST"
        case 17: return "K"
        case 23: return "FLEX"
        default: return "BN"
        }
    }
}