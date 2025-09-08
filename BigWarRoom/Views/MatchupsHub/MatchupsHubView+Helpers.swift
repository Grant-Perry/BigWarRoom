//
//  MatchupsHubView+Helpers.swift
//  BigWarRoom
//
//  Helper functions and computed properties for MatchupsHubView
//

import SwiftUI

// MARK: - Helpers & Computed Properties
extension MatchupsHubView {
    
    // MARK: - Computed Properties
    var sortedMatchups: [UnifiedMatchup] {
        let matchups = viewModel.myMatchups
        
        if sortByWinning {
            return matchups.sorted { matchup1, matchup2 in
                let score1 = matchup1.myTeam?.currentScore ?? 0
                let score2 = matchup2.myTeam?.currentScore ?? 0
                return score1 > score2
            }
        } else {
            return matchups.sorted { matchup1, matchup2 in
                let score1 = matchup1.myTeam?.currentScore ?? 0
                let score2 = matchup2.myTeam?.currentScore ?? 0
                return score1 < score2
            }
        }
    }
    
    var liveMatchupsCount: Int {
        sortedMatchups.filter { matchup in
            if matchup.isChoppedLeague {
                return false
            }
            
            guard let myTeam = matchup.myTeam else { return false }
            let starters = myTeam.roster.filter { $0.isStarter }
            return starters.contains { player in
                isPlayerInLiveGame(player)
            }
        }.count
    }
    
    var currentNFLWeek: Int {
        return selectedWeek
    }
    
    var connectedLeaguesCount: Int {
        Set(viewModel.myMatchups.map { $0.league.id }).count
    }
    
    // MARK: - Status Helper Functions
    func getWinningStatusForMatchup(_ matchup: UnifiedMatchup) -> Bool {
        if matchup.isChoppedLeague {
            guard let teamRanking = matchup.myTeamRanking else { return false }
            return teamRanking.eliminationStatus == .champion || teamRanking.eliminationStatus == .safe
        } else {
            guard let myTeam = matchup.myTeam,
                  let opponentTeam = matchup.opponentTeam else {
                return false
            }
            
            let myScore = myTeam.currentScore ?? 0
            let opponentScore = opponentTeam.currentScore ?? 0
            
            return myScore > opponentScore
        }
    }
    
    func getScoreColorForMatchup(_ matchup: UnifiedMatchup) -> Color {
        if matchup.isChoppedLeague {
            guard let ranking = matchup.myTeamRanking else { return .white }
            
            switch ranking.eliminationStatus {
            case .champion, .safe:
                return .gpGreen
            case .warning:
                return .gpYellow
            case .danger:
                return .orange
            case .critical, .eliminated:
                return .gpRedPink
            }
        } else {
            guard let myTeam = matchup.myTeam,
                  let opponentTeam = matchup.opponentTeam else {
                return .white
            }
            
            let myScore = myTeam.currentScore ?? 0
            let opponentScore = opponentTeam.currentScore ?? 0
            
            let isWinning = myScore > opponentScore
            return isWinning ? .gpGreen : .gpRedPink
        }
    }
    
    // MARK: - Game Status Functions
    func isPlayerInLiveGame(_ player: FantasyPlayer) -> Bool {
        guard let gameStatus = player.gameStatus else { return false }
        let timeString = gameStatus.timeString.lowercased()
        
        let quarterPatterns = ["1st ", "2nd ", "3rd ", "4th ", "ot ", "overtime"]
        for pattern in quarterPatterns {
            if timeString.contains(pattern) && timeString.contains(":") {
                return true
            }
        }
        
        let liveStatusIndicators = ["live", "halftime", "half", "end 1st", "end 2nd", "end 3rd", "end 4th"]
        return liveStatusIndicators.contains { timeString.contains($0) }
    }
    
    func isMatchupLive(_ matchup: UnifiedMatchup) -> Bool {
        guard let myTeam = matchup.myTeam else { return false }
        let starters = myTeam.roster.filter { $0.isStarter }
        return starters.contains { player in
            isPlayerInLiveGame(player)
        }
    }
    
    // MARK: - Micro Mode Helper Functions
    func calculateWinPercentageString(for matchup: UnifiedMatchup) -> String {
        if matchup.isChoppedLeague {
            guard let teamRanking = matchup.myTeamRanking else { return "0%" }
            return "\(Int(teamRanking.survivalProbability * 100))%"
        }
        
        guard let myScore = matchup.myTeam?.currentScore,
              let opponentScore = matchup.opponentTeam?.currentScore else { return "50%" }
        
        let totalScore = myScore + opponentScore
        if totalScore == 0 { return "50%" }
        
        let percentage = (myScore / totalScore) * 100.0
        return "\(Int(percentage))%"
    }
    
    // MARK: - Team Identification
    func identifyMyTeamInMatchup(_ matchup: UnifiedMatchup) -> (isMyTeamHome: Bool, myTeam: FantasyTeam?, opponentTeam: FantasyTeam?) {
        if matchup.isChoppedLeague {
            let myTeam = matchup.myTeam
            return (true, myTeam, nil)
        }
        
        guard let fantasyMatchup = matchup.fantasyMatchup else {
            return (true, nil, nil)
        }
        
        let homeTeam = fantasyMatchup.homeTeam
        let awayTeam = fantasyMatchup.awayTeam
        let homeScore = homeTeam.currentScore ?? 0
        let awayScore = awayTeam.currentScore ?? 0
        
        let homeIsWinning = homeScore > awayScore
        let isWinning = getWinningStatusForMatchup(matchup)
        
        if isWinning == homeIsWinning {
            return (true, homeTeam, awayTeam)
        } else {
            return (false, awayTeam, homeTeam)
        }
    }
    
    // MARK: - Utility Functions
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}