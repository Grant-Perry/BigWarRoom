//
//  ESPNFantasyService.swift
//  BigWarRoom
//
//  🔥 DRY: Single source of truth for ESPN fantasy data fetching and transformation
//  Extracted from FantasyViewModel+ESPN to follow MVVM and SRP
//

import Foundation

/// Service for handling all ESPN fantasy league operations
/// Handles API calls, data transformation, and team/player building
@MainActor
final class ESPNFantasyService {
    
    // MARK: - Dependencies
    private let apiClient: ESPNAPIClient
    private let gameStatusService: GameStatusService
    
    // MARK: - Initialization
    init(
        apiClient: ESPNAPIClient,
        gameStatusService: GameStatusService
    ) {
        self.apiClient = apiClient
        self.gameStatusService = gameStatusService
    }
    
    // MARK: - Public Interface
    
    /// Fetch ESPN fantasy data with proper authentication
    func fetchFantasyData(
        leagueID: String,
        week: Int,
        year: String
    ) async throws -> ESPNFantasyDataPackage {
        
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(week)") else {
            throw ESPNFantasyError.invalidURL
        }
        
        // Fetch full league data for member names and scoring settings
        let espnLeague = try await apiClient.fetchESPNLeagueData(leagueID: leagueID)
        DebugPrint(mode: .espnAPI, "Got league data with scoring settings for score breakdown")
        
        // Fetch standings for team records
        let standingsData = try await apiClient.fetchESPNStandings(leagueID: leagueID)
        DebugPrint(mode: .recordCalculation, "Got standings data for team records")
        
        // Extract team records from standings
        var teamRecords: [Int: TeamRecord] = [:]
        for team in standingsData.teams ?? [] {
            if let record = team.record?.overall {
                teamRecords[team.id] = TeamRecord(
                    wins: record.wins,
                    losses: record.losses,
                    ties: record.ties
                )
                DebugPrint(mode: .recordCalculation, limit: 10, "ESPN Standings Record: Team \(team.id) '\(team.displayName)': \(record.wins)-\(record.losses)")
            }
        }
        
        // Fetch matchup data
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = year == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
        
        DebugPrint(mode: .espnAPI, "📊 ESPN \(leagueID): \(model.teams.count) teams, \(model.schedule?.count ?? 0) schedule")
        
        return ESPNFantasyDataPackage(
            leagueModel: model,
            leagueData: espnLeague,
            teamRecords: teamRecords
        )
    }
    
    /// Process ESPN fantasy data into matchups and bye teams
    func processFantasyData(
        package: ESPNFantasyDataPackage,
        leagueID: String,
        week: Int,
        year: String
    ) -> ESPNProcessedData {
        
        var processedMatchups: [FantasyMatchup] = []
        var byeTeams: [FantasyTeam] = []
        
        // Store team names for lookup
        var teamNames: [Int: String] = [:]
        for team in package.leagueModel.teams {
            teamNames[team.id] = team.name
        }
        
        guard let schedule = package.leagueModel.schedule, !schedule.isEmpty else {
            DebugPrint(mode: .espnAPI, "⚠️ No schedule found - team is eliminated from playoffs")
            return ESPNProcessedData(
                matchups: [],
                byeTeams: [],
                teamRecords: package.teamRecords,
                teamNames: teamNames,
                leagueData: package.leagueData
            )
        }
        
        let weekSchedule = schedule.filter { $0.matchupPeriodId == week }
        
        for scheduleEntry in weekSchedule {
            // Handle bye weeks
            guard let awayTeamEntry = scheduleEntry.away else {
                // Check if this team appears as an away team in any other matchup
                let appearsAsAway = weekSchedule.contains { otherEntry in
                    otherEntry.away?.teamId == scheduleEntry.home.teamId
                }
                
                if appearsAsAway {
                    DebugPrint(mode: .espnAPI, "DUPLICATE: Team \(scheduleEntry.home.teamId) ALSO appears as away team in another entry!")
                }
                
                if let homeTeam = package.leagueModel.teams.first(where: { $0.id == scheduleEntry.home.teamId }) {
                    let homeScore = homeTeam.activeRosterScore(for: week)
                    let byeTeam = createFantasyTeam(
                        from: homeTeam,
                        score: homeScore,
                        leagueID: leagueID,
                        leagueData: package.leagueData,
                        teamRecords: package.teamRecords,
                        week: week
                    )
                    byeTeams.append(byeTeam)
                }
                continue
            }
            
            let awayTeamId = awayTeamEntry.teamId
            let homeTeamId = scheduleEntry.home.teamId
            
            guard let awayTeam = package.leagueModel.teams.first(where: { $0.id == awayTeamId }),
                  let homeTeam = package.leagueModel.teams.first(where: { $0.id == homeTeamId }) else {
                continue
            }
            
            // Calculate real ESPN scores
            let awayScore = awayTeam.activeRosterScore(for: week)
            let homeScore = homeTeam.activeRosterScore(for: week)
            
            let awayFantasyTeam = createFantasyTeam(
                from: awayTeam,
                score: awayScore,
                leagueID: leagueID,
                leagueData: package.leagueData,
                teamRecords: package.teamRecords,
                week: week
            )
            
            let homeFantasyTeam = createFantasyTeam(
                from: homeTeam,
                score: homeScore,
                leagueID: leagueID,
                leagueData: package.leagueData,
                teamRecords: package.teamRecords,
                week: week
            )
            
            let matchup = FantasyMatchup(
                id: "\(leagueID)_\(week)_\(awayTeamId)_\(homeTeamId)",
                leagueID: leagueID,
                week: week,
                year: year,
                homeTeam: homeFantasyTeam,
                awayTeam: awayFantasyTeam,
                status: .live,
                winProbability: WinProbabilityEngine.shared.calculateWinProbability(
                    myScore: homeScore,
                    opponentScore: awayScore
                ),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil
            )
            
            processedMatchups.append(matchup)
        }
        
        return ESPNProcessedData(
            matchups: processedMatchups.sorted { $0.homeTeam.ownerName < $1.homeTeam.ownerName },
            byeTeams: byeTeams,
            teamRecords: package.teamRecords,
            teamNames: teamNames,
            leagueData: package.leagueData
        )
    }
    
    /// Get ESPN scoring settings in Sleeper-compatible format
    func getScoringSettings(from leagueData: ESPNLeague) -> [String: Double]? {
        var scoringSettings: ESPNScoringSettings?
        
        // Try root level scoring settings first
        if let rootScoring = leagueData.scoringSettings {
            scoringSettings = rootScoring
        } else if let nestedScoring = leagueData.settings?.scoringSettings {
            scoringSettings = nestedScoring
        } else {
            return nil
        }
        
        guard let finalScoringSettings = scoringSettings,
              let scoringItems = finalScoringSettings.scoringItems else {
            return nil
        }
        
        var scoringMap: [String: Double] = [:]
        
        for item in scoringItems {
            guard let statId = item.statId,
                  let points = item.points else {
                continue
            }
            
            // Use direct ESPN stat ID to Sleeper key mapping
            if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                scoringMap[sleeperKey] = points
            }
        }
        
        return scoringMap.isEmpty ? nil : scoringMap
    }
    
    // MARK: - Private Helpers
    
    /// Create FantasyTeam from ESPN data
    private func createFantasyTeam(
        from espnTeam: ESPNFantasyTeamModel,
        score: Double,
        leagueID: String,
        leagueData: ESPNLeague,
        teamRecords: [Int: TeamRecord],
        week: Int
    ) -> FantasyTeam {
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        if let roster = espnTeam.roster {
            fantasyPlayers = roster.entries.map { entry in
                let player = entry.playerPoolEntry.player
                let weeklyScore = player.stats.first { stat in
                    stat.scoringPeriodId == week && stat.statSourceId == 0
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
                    gameStatus: gameStatusService.getGameStatusWithFallback(for: player.nflTeamAbbreviation),
                    isStarter: [0, 2, 3, 4, 5, 6, 23, 16, 17].contains(entry.lineupSlotId),
                    lineupSlot: positionString(entry.lineupSlotId),
                    injuryStatus: nil
                )
            }
        }
        
        // Use records from standings
        let record = teamRecords[espnTeam.id]
        
        // Resolve team name with better fallbacks
        let realTeamName: String = {
            // Try to get manager name from ESPN league member data
            if let espnTeamData = leagueData.teams?.first(where: { $0.id == espnTeam.id }) {
                let managerName = leagueData.getManagerName(for: espnTeamData.owners)
                
                // Don't use truncated fallback names
                if !managerName.hasPrefix("Manager ") && managerName.count > 4 {
                    return managerName
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
        
        return FantasyTeam(
            id: String(espnTeam.id),
            name: realTeamName,
            ownerName: realTeamName,
            record: record,
            avatar: nil,
            currentScore: score,
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: espnTeam.id,
            faabTotal: nil,
            faabUsed: nil
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

// MARK: - Data Models

/// Package of ESPN data fetched from API
struct ESPNFantasyDataPackage {
    let leagueModel: ESPNFantasyLeagueModel
    let leagueData: ESPNLeague
    let teamRecords: [Int: TeamRecord]
}

/// Processed ESPN data ready for ViewModel
struct ESPNProcessedData {
    let matchups: [FantasyMatchup]
    let byeTeams: [FantasyTeam]
    let teamRecords: [Int: TeamRecord]
    let teamNames: [Int: String]
    let leagueData: ESPNLeague
}

/// ESPN-specific errors
enum ESPNFantasyError: Error {
    case invalidURL
    case noScheduleData
    case teamNotFound
}