//
//  FantasyMatchupRosterSections.swift
//  BigWarRoom
//
//  PHASE 2 MVVM REFACTOR: Extracted View components from FantasyViewModel+UIHelpers
//  Proper MVVM separation - Views handle UI, ViewModel provides data
//  Moved from FantasyViewModel to proper View components
//

import SwiftUI

// MARK: - Active Roster Section

/// **Active Roster Section View**
/// **Extracted from FantasyViewModel+UIHelpers - proper MVVM separation**
struct FantasyMatchupActiveRosterSection: View {
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @Environment(NFLWeekService.self) private var nflWeekService
    
    @State private var homeProjected: Double = 0.0
    @State private var awayProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Active Roster")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            HStack(alignment: .top, spacing: 24) {
                // Away Team Active Roster (Left column - teamIndex 0)
                VStack(spacing: 16) {
                    let awayActiveRoster = getRoster(for: matchup, teamIndex: 0, isBench: false)
                    ForEach(awayActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: false,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    // Away team score with projections
                    teamScoreCard(
                        score: fantasyViewModel.getScore(for: matchup, teamIndex: 0),
                        projected: awayProjected,
                        isWinning: fantasyViewModel.getScore(for: matchup, teamIndex: 0) > fantasyViewModel.getScore(for: matchup, teamIndex: 1),
                        label: "Active Total"
                    )
                }
                
                // Home Team Active Roster (Right column - teamIndex 1)
                VStack(spacing: 16) {
                    let homeActiveRoster = getRoster(for: matchup, teamIndex: 1, isBench: false)
                    ForEach(homeActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: false,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    // Home team score with projections
                    teamScoreCard(
                        score: fantasyViewModel.getScore(for: matchup, teamIndex: 1),
                        projected: homeProjected,
                        isWinning: fantasyViewModel.getScore(for: matchup, teamIndex: 1) > fantasyViewModel.getScore(for: matchup, teamIndex: 0),
                        label: "Active Total"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .task {
            await loadProjectedScores()
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, projected: Double, isWinning: Bool, label: String) -> some View {
        if projectionsLoaded && projected > 0 {
            HStack(spacing: 4) {
                Text("*\(label)*: \(String(format: "%.2f", score))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("| (\(String(format: "%.1f", projected)))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text("*\(label)*: \(String(format: "%.2f", score))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        }
    }
    
    private func loadProjectedScores() async {
        let homeProj = await ProjectedPointsManager.shared.getProjectedTeamScore(for: matchup.homeTeam)
        let awayProj = await ProjectedPointsManager.shared.getProjectedTeamScore(for: matchup.awayTeam)
        
        await MainActor.run {
            self.homeProjected = homeProj
            self.awayProjected = awayProj
            self.projectionsLoaded = true
        }
    }
    
    /// Get roster for a team with proper position sorting
    private func getRoster(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        let filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        return filteredPlayers.sorted { player1, player2 in
            let order1 = positionSortOrder(player1.position)
            let order2 = positionSortOrder(player2.position)
            
            if order1 != order2 {
                return order1 < order2
            } else {
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return points1 > points2
            }
        }
    }
    
    /// Position sorting order: QB, WR, RB, TE, FLEX, Super Flex, K, D/ST
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }
}

// MARK: - Bench Section

/// **Bench Section View**
/// **Extracted from FantasyViewModel+UIHelpers - proper MVVM separation**
struct FantasyMatchupBenchSection: View {
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @Environment(NFLWeekService.self) private var nflWeekService
    
    @State private var homeBenchProjected: Double = 0.0
    @State private var awayBenchProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Bench")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            HStack(alignment: .top, spacing: 24) {
                // Away Team Bench (Left column - teamIndex 0)
                VStack(spacing: 16) {
                    let awayBenchRoster = getRoster(for: matchup, teamIndex: 0, isBench: true)
                    ForEach(awayBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: true,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    // Away team bench score with projections
                    let benchTotal = awayBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        projected: awayBenchProjected,
                        isWinning: false,
                        label: "Total"
                    )
                }
                
                // Home Team Bench (Right column - teamIndex 1)
                VStack(spacing: 16) {
                    let homeBenchRoster = getRoster(for: matchup, teamIndex: 1, isBench: true)
                    ForEach(homeBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: true,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    // Home team bench score with projections
                    let benchTotal = homeBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        projected: homeBenchProjected,
                        isWinning: false,
                        label: "Total"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .task {
            await loadBenchProjectedScores()
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, projected: Double, isWinning: Bool, label: String) -> some View {
        if projectionsLoaded && projected > 0 {
            HStack(spacing: 4) {
                Text("*\(label)*: \(String(format: "%.2f", score))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("| (\(String(format: "%.1f", projected)))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text("*\(label)*: \(String(format: "%.2f", score))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        }
    }
    
    private func loadBenchProjectedScores() async {
        let homeBenchPlayers = getRoster(for: matchup, teamIndex: 1, isBench: true)
        let awayBenchPlayers = getRoster(for: matchup, teamIndex: 0, isBench: true)
        
        var homeBenchProj = 0.0
        var awayBenchProj = 0.0
        
        for player in homeBenchPlayers {
            if let currentScore = player.currentPoints, currentScore > 0 {
                homeBenchProj += currentScore
            } else if let projection = await ProjectedPointsManager.shared.getProjectedPoints(for: player) {
                homeBenchProj += projection
            }
        }
        
        for player in awayBenchPlayers {
            if let currentScore = player.currentPoints, currentScore > 0 {
                awayBenchProj += currentScore
            } else if let projection = await ProjectedPointsManager.shared.getProjectedPoints(for: player) {
                awayBenchProj += projection
            }
        }
        
        await MainActor.run {
            self.homeBenchProjected = homeBenchProj
            self.awayBenchProjected = awayBenchProj
            self.projectionsLoaded = true
        }
    }
    
    /// Get roster for a team with proper position sorting
    private func getRoster(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        let filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        return filteredPlayers.sorted { player1, player2 in
            let order1 = positionSortOrder(player1.position)
            let order2 = positionSortOrder(player2.position)
            
            if order1 != order2 {
                return order1 < order2
            } else {
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return points1 > points2
            }
        }
    }
    
    /// Position sorting order: QB, WR, RB, TE, FLEX, Super Flex, K, D/ST
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }
}

// MARK: - Sorted Roster Sections (with Custom Sorting)

/// **Active Roster Section with Custom Sorting**
/// **Extracted from FantasyViewModel+UIHelpers - proper MVVM separation**
struct FantasyMatchupActiveRosterSectionSorted: View {
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    let sortMethod: MatchupSortingMethod
    let highToLow: Bool
    
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @Environment(NFLGameDataService.self) private var nflGameDataService
    @Environment(NFLWeekService.self) private var nflWeekService

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Active Roster")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            HStack(alignment: .top, spacing: 16) {
                // Away Team Active Roster (Left column - to match header)
                VStack(spacing: 16) {
                    let awayActiveRoster = getRosterSorted(for: matchup, teamIndex: 0, isBench: false)
                    ForEach(awayActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: false,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let homeScore = fantasyViewModel.getScore(for: matchup, teamIndex: 1)
                    let awayScore = fantasyViewModel.getScore(for: matchup, teamIndex: 0)
                    let awayWinning = awayScore > homeScore
                    
                    teamScoreCard(
                        score: awayScore,
                        isWinning: awayWinning,
                        label: "Active Total"
                    )
                }
                
                // Home Team Active Roster (Right column - to match header)
                VStack(spacing: 16) {
                    let homeActiveRoster = getRosterSorted(for: matchup, teamIndex: 1, isBench: false)
                    ForEach(homeActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: false,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let homeScore = fantasyViewModel.getScore(for: matchup, teamIndex: 1)
                    let awayScore = fantasyViewModel.getScore(for: matchup, teamIndex: 0)
                    let homeWinning = homeScore > awayScore
                    
                    teamScoreCard(
                        score: homeScore,
                        isWinning: homeWinning,
                        label: "Active Total"
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, isWinning: Bool, label: String) -> some View {
        Text("*\(label)*: \(String(format: "%.2f", score))")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(isWinning ? .gpGreen : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.secondarySystemBackground),
                                isWinning ? Color.gpGreen.opacity(0.2) : Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
    
    /// Get roster with custom sorting
    private func getRosterSorted(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        let filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        return filteredPlayers.sorted { player1, player2 in
            switch sortMethod {
            case .position:
                let order1 = positionSortOrder(player1.position)
                let order2 = positionSortOrder(player2.position)
                
                if order1 != order2 {
                    return highToLow ? order1 > order2 : order1 < order2
                } else {
                    let points1 = player1.currentPoints ?? 0.0
                    let points2 = player2.currentPoints ?? 0.0
                    return points1 > points2
                }
                
            case .score:
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return highToLow ? points1 > points2 : points1 < points2
                
            case .name:
                let name1 = player1.fullName.lowercased()
                let name2 = player2.fullName.lowercased()
                return highToLow ? name1 > name2 : name1 < name2
                
            case .team:
                let team1 = player1.team?.lowercased() ?? ""
                let team2 = player2.team?.lowercased() ?? ""
                return highToLow ? team1 > team2 : team1 < team2
                
            case .recentActivity:
                // 🔥 FIX: Sort by lastActivityTime first (most recent activity first)
                let time1 = player1.lastActivityTime ?? Date.distantPast
                let time2 = player2.lastActivityTime ?? Date.distantPast
                
                if time1 != time2 {
                    return time1 > time2 // Most recent first
                }
                
                // Fallback: Live players next
                let live1 = player1.isLive(gameDataService: nflGameDataService)
                let live2 = player2.isLive(gameDataService: nflGameDataService)
                
                if live1 != live2 {
                    return live1
                }
                
                // Then by score
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return points1 > points2
            }
        }
    }
    
    /// Position sorting order
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }
}

/// **Bench Section with Custom Sorting**
/// **Extracted from FantasyViewModel+UIHelpers - proper MVVM separation**
struct FantasyMatchupBenchSectionSorted: View {
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    let sortMethod: MatchupSortingMethod
    let highToLow: Bool
    
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @Environment(NFLGameDataService.self) private var nflGameDataService
    @Environment(NFLWeekService.self) private var nflWeekService

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Bench")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            HStack(alignment: .top, spacing: 16) {
                // Away Team Bench (Left column - to match header)
                VStack(spacing: 16) {
                    let awayBenchRoster = getRosterSorted(for: matchup, teamIndex: 0, isBench: true)
                    ForEach(awayBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: true,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let benchTotal = awayBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        isWinning: false,
                        label: "Total"
                    )
                }
                
                // Home Team Bench (Right column - to match header)
                VStack(spacing: 16) {
                    let homeBenchRoster = getRosterSorted(for: matchup, teamIndex: 1, isBench: true)
                    ForEach(homeBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: true,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let benchTotal = homeBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        isWinning: false,
                        label: "Total"
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, isWinning: Bool, label: String) -> some View {
        Text("*\(label)*: \(String(format: "%.2f", score))")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
    
    /// Get roster with custom sorting
    private func getRosterSorted(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        let filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        return filteredPlayers.sorted { player1, player2 in
            switch sortMethod {
            case .position:
                let order1 = positionSortOrder(player1.position)
                let order2 = positionSortOrder(player2.position)
                
                if order1 != order2 {
                    return highToLow ? order1 > order2 : order1 < order2
                } else {
                    let points1 = player1.currentPoints ?? 0.0
                    let points2 = player2.currentPoints ?? 0.0
                    return points1 > points2
                }
                
            case .score:
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return highToLow ? points1 > points2 : points1 < points2
                
            case .name:
                let name1 = player1.fullName.lowercased()
                let name2 = player2.fullName.lowercased()
                return highToLow ? name1 > name2 : name1 < name2
                
            case .team:
                let team1 = player1.team?.lowercased() ?? ""
                let team2 = player2.team?.lowercased() ?? ""
                return highToLow ? team1 > team2 : team1 < team2
                
            case .recentActivity:
                // 🔥 FIX: Sort by lastActivityTime first (most recent activity first)
                let time1 = player1.lastActivityTime ?? Date.distantPast
                let time2 = player2.lastActivityTime ?? Date.distantPast
                
                if time1 != time2 {
                    return time1 > time2 // Most recent first
                }
                
                // Fallback: Live players next
                let live1 = player1.isLive(gameDataService: nflGameDataService)
                let live2 = player2.isLive(gameDataService: nflGameDataService)
                
                if live1 != live2 {
                    return live1
                }
                
                // Then by score
                let p1 = player1.currentPoints ?? 0.0
                let p2 = player2.currentPoints ?? 0.0
                return p1 > p2
            }
        }
    }
    
    /// Position sorting order
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }
}

// MARK: - Filtered Roster Sections

/// **Active Roster Section with Full Filtering Capabilities**
struct FantasyMatchupActiveRosterSectionFiltered: View {
    @Environment(MatchupsHubViewModel.self) private var matchupsHub
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @Environment(NFLGameDataService.self) private var nflGameDataService
    @Environment(NFLWeekService.self) private var nflWeekService

    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    let sortMethod: MatchupSortingMethod
    let highToLow: Bool
    let selectedPosition: FantasyPosition
    let showActiveOnly: Bool
    let showYetToPlayOnly: Bool
    let hubUpdateTime: Date  // 🔥 NEW: Force re-compute when hub updates
    
    @State private var localSelectedPosition: FantasyPosition = .all
    @State private var localShowActiveOnly: Bool = false
    @State private var localShowYetToPlayOnly: Bool = false
    
    @State private var cachedHomeRoster: [FantasyPlayer] = []
    @State private var cachedAwayRoster: [FantasyPlayer] = []
    @State private var homeProjected: Double = 0.0
    @State private var awayProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    private var currentMatchup: FantasyMatchup {
        if let updated = matchupsHub.myMatchups.first(where: { $0.fantasyMatchup?.id == matchup.id })?.fantasyMatchup {
            return updated
        }
        return matchup
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 20) {
                    ForEach(cachedAwayRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: currentMatchup,
                            teamIndex: 0,
                            isBench: false,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let homeScore = fantasyViewModel.getScore(for: currentMatchup, teamIndex: 1)
                    let awayScore = fantasyViewModel.getScore(for: currentMatchup, teamIndex: 0)
                    let awayWinning = awayScore > homeScore
                    
                    teamScoreCard(
                        score: awayScore,
                        projected: awayProjected,
                        isWinning: awayWinning,
                        label: "Total"
                    )
                }
                
                VStack(spacing: 20) {
                    ForEach(cachedHomeRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: currentMatchup,
                            teamIndex: 1,
                            isBench: false,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let homeScore = fantasyViewModel.getScore(for: currentMatchup, teamIndex: 1)
                    let awayScore = fantasyViewModel.getScore(for: currentMatchup, teamIndex: 0)
                    let homeWinning = homeScore > awayScore
                    
                    teamScoreCard(
                        score: homeScore,
                        projected: homeProjected,
                        isWinning: homeWinning,
                        label: "Total"
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            syncLocalFilters()
            updateCachedRosters()
            Task {
                await loadProjectedScores()
            }
        }
        .onChange(of: sortMethod) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: highToLow) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: selectedPosition) { _, newValue in
            localSelectedPosition = newValue
            updateCachedRosters()
        }
        .onChange(of: showActiveOnly) { _, newValue in
            localShowActiveOnly = newValue
            updateCachedRosters()
        }
        .onChange(of: showYetToPlayOnly) { _, newValue in
            localShowYetToPlayOnly = newValue
            updateCachedRosters()
        }
        .onChange(of: hubUpdateTime) { _, _ in
            // 🔥 NEW: Hub updated - refresh rosters with new data
            updateCachedRosters()
        }
    }
    
    private func syncLocalFilters() {
        localSelectedPosition = selectedPosition
        localShowActiveOnly = showActiveOnly
        localShowYetToPlayOnly = showYetToPlayOnly
    }
    
    private func updateCachedRosters() {
        cachedHomeRoster = getFilteredRoster(forTeam: currentMatchup.homeTeam, isBench: false)
        cachedAwayRoster = getFilteredRoster(forTeam: currentMatchup.awayTeam, isBench: false)
    }
    
    private func loadProjectedScores() async {
        let homeProj = await ProjectedPointsManager.shared.getProjectedTeamScore(for: currentMatchup.homeTeam)
        let awayProj = await ProjectedPointsManager.shared.getProjectedTeamScore(for: currentMatchup.awayTeam)
        
        await MainActor.run {
            self.homeProjected = homeProj
            self.awayProjected = awayProj
            self.projectionsLoaded = true
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, projected: Double, isWinning: Bool, label: String) -> some View {
        if projectionsLoaded && projected > 0 {
            HStack(spacing: 4) {
                Text("*\(label)*: \(String(format: "%.2f", score))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("| (\(String(format: "%.1f", projected)))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text("*\(label)*: \(String(format: "%.2f", score))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        }
    }
    
    private func getFilteredRoster(forTeam team: FantasyTeam, isBench: Bool) -> [FantasyPlayer] {
        var filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        if localSelectedPosition != .all {
            filteredPlayers = filteredPlayers.filter { player in
                let playerPosition = player.position.uppercased()
                let filterPosition = localSelectedPosition.rawValue.uppercased()
                
                if filterPosition == "D/ST" {
                    return playerPosition == "D/ST" || playerPosition == "DST" || playerPosition == "DEF"
                }
                
                return playerPosition == filterPosition
            }
        }
        
        if localShowActiveOnly {
            let liveTeams = Set(nflGameDataService.gameData.values
                .filter { $0.isLive }
                .flatMap { [$0.homeTeam, $0.awayTeam] })
            
            filteredPlayers = filteredPlayers.filter { player in
                guard let playerTeam = player.team else { return false }
                return liveTeams.contains(playerTeam)
            }
        }
        
        if localShowYetToPlayOnly {
            filteredPlayers = filteredPlayers.filter { player in
                GameStatusService.shared.isPlayerYetToPlay(
                    playerTeam: player.team,
                    currentPoints: player.currentPoints
                )
            }
        }
        
        filteredPlayers = filteredPlayers.sorted { player1, player2 in
            switch sortMethod {
            case .position:
                let order1 = positionSortOrder(player1.position)
                let order2 = positionSortOrder(player2.position)
                
                if order1 != order2 {
                    return highToLow ? order1 > order2 : order1 < order2
                } else {
                    let points1 = player1.currentPoints ?? 0.0
                    let points2 = player2.currentPoints ?? 0.0
                    return points1 > points2
                }
                
            case .score:
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return highToLow ? points1 > points2 : points1 < points2
                
            case .name:
                let name1 = player1.fullName.lowercased()
                let name2 = player2.fullName.lowercased()
                return highToLow ? name1 > name2 : name1 < name2
                
            case .team:
                let team1 = player1.team?.lowercased() ?? ""
                let team2 = player2.team?.lowercased() ?? ""
                return highToLow ? team1 > team2 : team1 < team2
                
            case .recentActivity:
                // 🔥 FIX: Sort by lastActivityTime first (most recent activity first)
                let time1 = player1.lastActivityTime ?? Date.distantPast
                let time2 = player2.lastActivityTime ?? Date.distantPast
                
                if time1 != time2 {
                    return time1 > time2 // Most recent first
                }
                
                // Fallback: Live players next
                let live1 = player1.isLive(gameDataService: nflGameDataService)
                let live2 = player2.isLive(gameDataService: nflGameDataService)
                
                if live1 != live2 {
                    return live1
                }
                
                // Then by score
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return points1 > points2
            }
        }
        
        return filteredPlayers
    }
    
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }
}

/// **Bench Section with Full Filtering Capabilities**
struct FantasyMatchupBenchSectionFiltered: View {
    @Environment(MatchupsHubViewModel.self) private var matchupsHub
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @Environment(NFLGameDataService.self) private var nflGameDataService
    @Environment(NFLWeekService.self) private var nflWeekService

    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    let sortMethod: MatchupSortingMethod
    let highToLow: Bool
    let selectedPosition: FantasyPosition
    let showActiveOnly: Bool
    let showYetToPlayOnly: Bool
    let hubUpdateTime: Date  // 🔥 NEW: Force re-compute when hub updates

    @State private var localSelectedPosition: FantasyPosition = .all
    @State private var localShowActiveOnly: Bool = false
    @State private var localShowYetToPlayOnly: Bool = false
    
    @State private var cachedHomeBench: [FantasyPlayer] = []
    @State private var cachedAwayBench: [FantasyPlayer] = []
    @State private var homeBenchProjected: Double = 0.0
    @State private var awayBenchProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    private var currentMatchup: FantasyMatchup {
        if let updated = matchupsHub.myMatchups.first(where: { $0.fantasyMatchup?.id == matchup.id })?.fantasyMatchup {
            return updated
        }
        return matchup
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bench")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 20) {
                    ForEach(cachedAwayBench, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: currentMatchup,
                            teamIndex: 0,
                            isBench: true,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let benchTotal = cachedAwayBench.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        projected: awayBenchProjected,
                        isWinning: false,
                        label: "Total"
                    )
                }
                
                VStack(spacing: 20) {
                    ForEach(cachedHomeBench, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: currentMatchup,
                            teamIndex: 1,
                            isBench: true,
                            allLivePlayersViewModel: allLivePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                    }
                    
                    let benchTotal = cachedHomeBench.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        projected: homeBenchProjected,
                        isWinning: false,
                        label: "Total"
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            syncLocalFilters()
            updateCachedRosters()
            Task {
                await loadBenchProjectedScores()
            }
        }
        .onChange(of: sortMethod) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: highToLow) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: selectedPosition) { _, newValue in
            localSelectedPosition = newValue
            updateCachedRosters()
        }
        .onChange(of: showActiveOnly) { _, newValue in
            localShowActiveOnly = newValue
            updateCachedRosters()
        }
        .onChange(of: showYetToPlayOnly) { _, newValue in
            localShowYetToPlayOnly = newValue
            updateCachedRosters()
        }
        .onChange(of: hubUpdateTime) { _, _ in
            // 🔥 NEW: Hub updated - refresh rosters with new data
            updateCachedRosters()
        }
    }
    
    private func syncLocalFilters() {
        localSelectedPosition = selectedPosition
        localShowActiveOnly = showActiveOnly
        localShowYetToPlayOnly = showYetToPlayOnly
    }
    
    private func updateCachedRosters() {
        cachedHomeBench = getFilteredRoster(forTeam: currentMatchup.homeTeam, isBench: true)
        cachedAwayBench = getFilteredRoster(forTeam: currentMatchup.awayTeam, isBench: true)
    }
    
    private func loadBenchProjectedScores() async {
        let homeBenchPlayers = getFilteredRoster(forTeam: currentMatchup.homeTeam, isBench: true)
        let awayBenchPlayers = getFilteredRoster(forTeam: currentMatchup.awayTeam, isBench: true)
        
        var homeBenchProj = 0.0
        var awayBenchProj = 0.0
        
        for player in homeBenchPlayers {
            if let currentScore = player.currentPoints, currentScore > 0 {
                homeBenchProj += currentScore
            } else if let projection = await ProjectedPointsManager.shared.getProjectedPoints(for: player) {
                homeBenchProj += projection
            }
        }
        
        for player in awayBenchPlayers {
            if let currentScore = player.currentPoints, currentScore > 0 {
                awayBenchProj += currentScore
            } else if let projection = await ProjectedPointsManager.shared.getProjectedPoints(for: player) {
                awayBenchProj += projection
            }
        }
        
        await MainActor.run {
            self.homeBenchProjected = homeBenchProj
            self.awayBenchProjected = awayBenchProj
            self.projectionsLoaded = true
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, projected: Double, isWinning: Bool, label: String) -> some View {
        if projectionsLoaded && projected > 0 {
            HStack(spacing: 4) {
                Text("*\(label)*: \(String(format: "%.2f", score))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("| (\(String(format: "%.1f", projected)))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text("*\(label)*: \(String(format: "%.2f", score))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        }
    }
    
    private func getFilteredRoster(forTeam team: FantasyTeam, isBench: Bool) -> [FantasyPlayer] {
        var filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        if localSelectedPosition != .all {
            filteredPlayers = filteredPlayers.filter { player in
                let playerPosition = player.position.uppercased()
                let filterPosition = localSelectedPosition.rawValue.uppercased()
                
                if filterPosition == "D/ST" {
                    return playerPosition == "D/ST" || playerPosition == "DST" || playerPosition == "DEF"
                }
                
                return playerPosition == filterPosition
            }
        }
        
        if localShowActiveOnly {
            let liveTeams = Set(nflGameDataService.gameData.values
                .filter { $0.isLive }
                .flatMap { [$0.homeTeam, $0.awayTeam] })
            
            filteredPlayers = filteredPlayers.filter { player in
                guard let playerTeam = player.team else { return false }
                return liveTeams.contains(playerTeam)
            }
        }
        
        if localShowYetToPlayOnly {
            filteredPlayers = filteredPlayers.filter { player in
                GameStatusService.shared.isPlayerYetToPlay(
                    playerTeam: player.team,
                    currentPoints: player.currentPoints
                )
            }
        }
        
        filteredPlayers = filteredPlayers.sorted { player1, player2 in
            switch sortMethod {
            case .position:
                let order1 = positionSortOrder(player1.position)
                let order2 = positionSortOrder(player2.position)
                
                if order1 != order2 {
                    return highToLow ? order1 > order2 : order1 < order2
                } else {
                    let points1 = player1.currentPoints ?? 0.0
                    let points2 = player2.currentPoints ?? 0.0
                    return points1 > points2
                }
                
            case .score:
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return highToLow ? points1 > points2 : points1 < points2
                
            case .name:
                let name1 = player1.fullName.lowercased()
                let name2 = player2.fullName.lowercased()
                return highToLow ? name1 > name2 : name1 < name2
                
            case .team:
                let team1 = player1.team?.lowercased() ?? ""
                let team2 = player2.team?.lowercased() ?? ""
                return highToLow ? team1 > team2 : team1 < team2
                
            case .recentActivity:
                // 🔥 FIX: Sort by lastActivityTime first (most recent activity first)
                let time1 = player1.lastActivityTime ?? Date.distantPast
                let time2 = player2.lastActivityTime ?? Date.distantPast
                
                if time1 != time2 {
                    return time1 > time2 // Most recent first
                }
                
                // Fallback: Live players next
                let live1 = player1.isLive(gameDataService: nflGameDataService)
                let live2 = player2.isLive(gameDataService: nflGameDataService)
                
                if live1 != live2 {
                    return live1
                }
                
                // Then by score
                let p1 = player1.currentPoints ?? 0.0
                let p2 = player2.currentPoints ?? 0.0
                return p1 > p2
            }
        }
        
        return filteredPlayers
    }
    
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }
}