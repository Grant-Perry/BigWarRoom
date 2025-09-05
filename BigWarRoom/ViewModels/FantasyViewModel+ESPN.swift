//
//  FantasyViewModel+ESPN.swift
//  BigWarRoom
//
//  ESPN Fantasy League functionality for FantasyViewModel
//

import Foundation
import Combine

// MARK: -> ESPN Fantasy Data Extension
extension FantasyViewModel {
    
    /// Fetch real ESPN fantasy data with proper authentication
    func fetchESPNFantasyData(leagueID: String, week: Int) async {
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(selectedYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&scoringPeriodId=\(week)") else {
            errorMessage = "Invalid ESPN API URL"
            return
        }
        
        print("🔍 ESPN: Fetching \(leagueID) week \(week)")
        
        // 🔥 FIX: First fetch the full league data with member info for name resolution
        do {
            currentESPNLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: leagueID)
            print("✅ ESPN: Got league member data for name resolution")
        } catch {
            print("⚠️ ESPN: Failed to get league member data, using fallback names")
            currentESPNLeague = nil
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = selectedYear == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                NSLog("📡 ESPN: Received \(data.count) bytes for \(leagueID)")
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let schedule = json["schedule"] as? [[String: Any]] {
                    NSLog("📊 ESPN: \(leagueID) has \(schedule.count) total schedule entries")
                    
                    let currentWeekEntries = schedule.filter { entry in
                        if let matchupPeriodId = entry["matchupPeriodId"] as? Int {
                            return matchupPeriodId == week
                        }
                        return false
                    }
                    NSLog("🏈 ESPN: \(leagueID) has \(currentWeekEntries.count) entries for week \(week)")
                }
            })
            .decode(type: ESPNFantasyLeagueModel.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    NSLog("❌ ESPN Decode Error for \(leagueID): \(error)")
                    self?.tryAlternateTokenSync(url: url, leagueID: leagueID, week: week)
                case .finished:
                    NSLog("✅ ESPN Success for \(leagueID)")
                }
            }, receiveValue: { [weak self] model in
                NSLog("📊 ESPN \(leagueID): \(model.teams.count) teams, \(model.schedule.count) schedule")
                Task {
                    await self?.processESPNFantasyData(espnModel: model, leagueID: leagueID, week: week)
                }
            })
            .store(in: &cancellables)
    }
    
    /// Try alternate ESPN token synchronously
    private func tryAlternateTokenSync(url: URL, leagueID: String, week: Int) {
        let alternateToken = selectedYear == "2025" ? AppConstants.ESPN_S2 : AppConstants.ESPN_S2_2025
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(alternateToken)", forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure:
                    self?.debugScheduleStructure(data: nil, leagueID: leagueID)
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] data in
                self?.debugScheduleStructure(data: data, leagueID: leagueID)
            })
            .store(in: &cancellables)
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
        print("🏈 ESPN \(leagueID): Week \(week) has \(weekSchedule.count) matchups")
        
        for scheduleEntry in weekSchedule {
            // Handle bye weeks
            guard let awayTeamEntry = scheduleEntry.away else {
                NSLog("🛌 ESPN: Found bye week for team \(scheduleEntry.home.teamId)")
                
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
        
        print("🎯 ESPN \(leagueID): Created \(processedMatchups.count) matchups and \(byeTeams.count) bye week teams")
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
                    firstName: extractFirstName(from: player.fullName),
                    lastName: extractLastName(from: player.fullName),
                    position: positionString(entry.lineupSlotId),
                    team: player.nflTeamAbbreviation,
                    jerseyNumber: nil,
                    currentPoints: weeklyScore,
                    projectedPoints: weeklyScore * 1.1,
                    gameStatus: createMockGameStatus(),
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
    
    /// Extract first name from full name
    private func extractFirstName(from fullName: String?) -> String? {
        guard let fullName = fullName else { return nil }
        return String(fullName.split(separator: " ").first ?? "")
    }
    
    /// Extract last name from full name
    private func extractLastName(from fullName: String?) -> String? {
        guard let fullName = fullName else { return nil }
        let components = fullName.split(separator: " ")
        return components.count > 1 ? String(components.last!) : nil
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