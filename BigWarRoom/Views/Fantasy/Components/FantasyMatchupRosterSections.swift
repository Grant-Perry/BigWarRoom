//
//  FantasyMatchupRosterSections.swift
//  BigWarRoom
//
//  🔥 PHASE 2 MVVM REFACTOR: Extracted View components from FantasyViewModel+UIHelpers
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
                            isBench: false
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
                            isBench: false
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
                Text("\(label): \(String(format: "%.2f", score))")
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
            Text("\(label): \(String(format: "%.2f", score))")
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
                            isBench: true
                        )
                    }
                    
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
                            isBench: true
                        )
                    }
                    
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
            Text("\(label): \(String(format: "%.2f", score)) | (\(String(format: "%.1f", projected)))")
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text("\(label): \(String(format: "%.2f", score))")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Active Roster")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            HStack(alignment: .top, spacing: 16) {
                // Home Team Active Roster (Left column - to match header)
                VStack(spacing: 16) {
                    let homeActiveRoster = getRosterSorted(for: matchup, teamIndex: 1, isBench: false)
                    ForEach(homeActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: false
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
                
                // Away Team Active Roster (Right column - to match header)
                VStack(spacing: 16) {
                    let awayActiveRoster = getRosterSorted(for: matchup, teamIndex: 0, isBench: false)
                    ForEach(awayActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: false
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
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, isWinning: Bool, label: String) -> some View {
        Text("\(label): \(String(format: "%.2f", score))")
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
                    // If same position, sort by score (high to low)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Bench")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            HStack(alignment: .top, spacing: 16) {
                // Home Team Bench (Left column - to match header)
                VStack(spacing: 16) {
                    let homeBenchRoster = getRosterSorted(for: matchup, teamIndex: 1, isBench: true)
                    ForEach(homeBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: true
                        )
                    }
                    
                    let benchTotal = homeBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        isWinning: false,
                        label: "Bench Total"
                    )
                }
                
                // Away Team Bench (Right column - to match header)
                VStack(spacing: 16) {
                    let awayBenchRoster = getRosterSorted(for: matchup, teamIndex: 0, isBench: true)
                    ForEach(awayBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: true
                        )
                    }
                    
                    let benchTotal = awayBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        isWinning: false,
                        label: "Bench Total"
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func teamScoreCard(score: Double, isWinning: Bool, label: String) -> some View {
        Text("\(label): \(String(format: "%.2f", score))")
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

// MARK: - FILTERED Roster Sections (with comprehensive filtering)

/// **Active Roster Section with Full Filtering Capabilities**
struct FantasyMatchupActiveRosterSectionFiltered: View {
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    let sortMethod: MatchupSortingMethod
    let highToLow: Bool
    let selectedPosition: FantasyPosition
    let showActiveOnly: Bool
    let showYetToPlayOnly: Bool
    
    @State private var cachedHomeRoster: [FantasyPlayer] = []
    @State private var cachedAwayRoster: [FantasyPlayer] = []
    @State private var lastFilterUpdate = Date.distantPast
    @State private var homeProjected: Double = 0.0
    @State private var awayProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(alignment: .top, spacing: 24) {
                // Home Team Active Roster (Left column - to match header)
                VStack(spacing: 20) {
                    ForEach(homeActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: false
                        )
                    }
                    
                    let homeScore = fantasyViewModel.getScore(for: matchup, teamIndex: 1)
                    let awayScore = fantasyViewModel.getScore(for: matchup, teamIndex: 0)
                    let homeWinning = homeScore > awayScore
                    
                    teamScoreCard(
                        score: homeScore,
                        projected: homeProjected,
                        isWinning: homeWinning,
                        label: "Total"
                    )
                }
                
                // Away Team Active Roster (Right column - to match header)
                VStack(spacing: 20) {
                    ForEach(awayActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: false
                        )
                    }
                    
                    let homeScore = fantasyViewModel.getScore(for: matchup, teamIndex: 1)
                    let awayScore = fantasyViewModel.getScore(for: matchup, teamIndex: 0)
                    let awayWinning = awayScore > homeScore
                    
                    teamScoreCard(
                        score: awayScore,
                        projected: awayProjected,
                        isWinning: awayWinning,
                        label: "Total"
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
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
        .onChange(of: selectedPosition) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: showActiveOnly) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: showYetToPlayOnly) { _, _ in
            updateCachedRosters()
        }
    }
    
    private var homeActiveRoster: [FantasyPlayer] {
        // 🔥 FIX: Return fresh data directly instead of cached (parent forces rebuild via .id())
        return getFilteredRoster(for: matchup, teamIndex: 1, isBench: false)
    }
    
    private var awayActiveRoster: [FantasyPlayer] {
        // 🔥 FIX: Return fresh data directly instead of cached (parent forces rebuild via .id())
        return getFilteredRoster(for: matchup, teamIndex: 0, isBench: false)
    }
    
    private func updateCachedRosters() {
        cachedHomeRoster = getFilteredRoster(for: matchup, teamIndex: 1, isBench: false)
        cachedAwayRoster = getFilteredRoster(for: matchup, teamIndex: 0, isBench: false)
        lastFilterUpdate = Date()
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
    
    @ViewBuilder
    private func teamScoreCard(score: Double, projected: Double, isWinning: Bool, label: String) -> some View {
        if projectionsLoaded && projected > 0 {
            HStack(spacing: 4) {
                Text("\(label): \(String(format: "%.2f", score))")
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
            Text("\(label): \(String(format: "%.2f", score))")
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
    
    /// Get roster with comprehensive filtering and sorting
    private func getFilteredRoster(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        
        var filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        if selectedPosition != .all {
            filteredPlayers = filteredPlayers.filter { player in
                let playerPosition = player.position.uppercased()
                let filterPosition = selectedPosition.rawValue.uppercased()
                
                if filterPosition == "D/ST" {
                    return playerPosition == "D/ST" || playerPosition == "DST" || playerPosition == "DEF"
                }
                
                return playerPosition == filterPosition
            }
        }
        
        if showActiveOnly {
            let liveTeams = Set(NFLGameDataService.shared.gameData.values
                .filter { $0.isLive }
                .flatMap { [$0.homeTeam, $0.awayTeam] })
            
            filteredPlayers = filteredPlayers.filter { player in
                guard let playerTeam = player.team else { return false }
                return liveTeams.contains(playerTeam)
            }
        }
        
        if showYetToPlayOnly {
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
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    let sortMethod: MatchupSortingMethod
    let highToLow: Bool
    let selectedPosition: FantasyPosition
    let showActiveOnly: Bool
    let showYetToPlayOnly: Bool
    
    @State private var cachedHomeBench: [FantasyPlayer] = []
    @State private var cachedAwayBench: [FantasyPlayer] = []
    @State private var lastFilterUpdate = Date.distantPast
    @State private var homeBenchProjected: Double = 0.0
    @State private var awayBenchProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bench")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            HStack(alignment: .top, spacing: 24) {
                // Home Team Bench (Left column - to match header)
                VStack(spacing: 20) {
                    ForEach(homeBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: true
                        )
                    }
                    
                    let benchTotal = homeBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        projected: homeBenchProjected,
                        isWinning: false,
                        label: "Total"
                    )
                }
                
                // Away Team Bench (Right column - to match header)
                VStack(spacing: 20) {
                    ForEach(awayBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: true
                        )
                    }
                    
                    let benchTotal = awayBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    teamScoreCard(
                        score: benchTotal,
                        projected: awayBenchProjected,
                        isWinning: false,
                        label: "Total"
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
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
        .onChange(of: selectedPosition) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: showActiveOnly) { _, _ in
            updateCachedRosters()
        }
        .onChange(of: showYetToPlayOnly) { _, _ in
            updateCachedRosters()
        }
    }
    
    private var homeBenchRoster: [FantasyPlayer] {
        // 🔥 FIX: Return fresh data directly instead of cached (parent forces rebuild via .id())
        return getFilteredRoster(for: matchup, teamIndex: 1, isBench: true)
    }
    
    private var awayBenchRoster: [FantasyPlayer] {
        // 🔥 FIX: Return fresh data directly instead of cached (parent forces rebuild via .id())
        return getFilteredRoster(for: matchup, teamIndex: 0, isBench: true)
    }
    
    private func updateCachedRosters() {
        cachedHomeBench = getFilteredRoster(for: matchup, teamIndex: 1, isBench: true)
        cachedAwayBench = getFilteredRoster(for: matchup, teamIndex: 0, isBench: true)
        lastFilterUpdate = Date()
    }
    
    private func loadBenchProjectedScores() async {
        let homeBenchPlayers = homeBenchRoster
        let awayBenchPlayers = awayBenchRoster
        
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
                Text("\(label): \(String(format: "%.2f", score))")
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
            Text("\(label): \(String(format: "%.2f", score))")
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
    
    private func getFilteredRoster(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        
        var filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        if selectedPosition != .all {
            filteredPlayers = filteredPlayers.filter { player in
                let playerPosition = player.position.uppercased()
                let filterPosition = selectedPosition.rawValue.uppercased()
                
                if filterPosition == "D/ST" {
                    return playerPosition == "D/ST" || playerPosition == "DST" || playerPosition == "DEF"
                }
                
                return playerPosition == filterPosition
            }
        }
        
        if showActiveOnly {
            let liveTeams = Set(NFLGameDataService.shared.gameData.values
                .filter { $0.isLive }
                .flatMap { [$0.homeTeam, $0.awayTeam] })
            
            filteredPlayers = filteredPlayers.filter { player in
                guard let playerTeam = player.team else { return false }
                return liveTeams.contains(playerTeam)
            }
        }
        
        if showYetToPlayOnly {
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