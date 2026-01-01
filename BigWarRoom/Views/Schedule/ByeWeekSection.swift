//
//  ByeWeekSection.swift
//  BigWarRoom
//
//  Displays NFL teams on BYE week in the Schedule view
//
// MARK: -> Schedule Bye Week Section

import SwiftUI

struct ScheduleByeWeekSection: View {
    let byeTeams: [NFLTeam]
    let unifiedLeagueManager: UnifiedLeagueManager
    let matchupsHubViewModel: MatchupsHubViewModel
    let weekSelectionManager: WeekSelectionManager
    let standingsService: NFLStandingsService
    let teamAssetManager: TeamAssetManager
    
    @State private var byeWeekImpacts: [String: ByeWeekImpact] = [:]
    @State private var isLoadingImpacts = false
    @State private var selectedImpactItem: ByeWeekImpactItem?  // 🔥 FIX: Use Identifiable item for sheet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with week number
            HStack {
                Text("BYE - Week \(weekSelectionManager.selectedWeek)")
                    .font(.system(size: 16, weight: .black, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(byeTeams.count) teams")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                // Loading indicator while analyzing impact
                if isLoadingImpacts {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            
            // Teams grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(byeTeams) { team in
                    ScheduleByeTeamCell(
                        team: team,
                        byeWeekImpact: byeWeekImpacts[team.id],
                        isLoadingImpacts: isLoadingImpacts,
                        standingsService: standingsService,
                        teamAssetManager: teamAssetManager
                    ) {
                        // 🔥 ONLY open sheet if impact exists AND has problems
                        if let impact = byeWeekImpacts[team.id], impact.hasProblem {
                            selectedImpactItem = ByeWeekImpactItem(impact: impact, team: team)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Legend explanation
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("No rostered players affected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gpRedPink)
                        Text("You have rostered players on BYE")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                HStack(spacing: 3) {
                    Text("Tap teams with")
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gpRedPink)
                    Text("to see affected matchups")
                }
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
                .italic()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(.vertical, 16)
        .task {
            await analyzeByeWeekImpacts()
        }
        .onChange(of: weekSelectionManager.selectedWeek) { _, _ in
            Task {
                await analyzeByeWeekImpacts()
            }
        }
        .sheet(item: $selectedImpactItem) { item in
                ByeWeekPlayerImpactSheet(
                impact: item.impact,
                teamName: item.team.fullName,
                teamCode: item.team.id
                )
        }
    }
    
    // MARK: - Analyze Bye Week Impacts
    
    private func analyzeByeWeekImpacts() async {
        isLoadingImpacts = true
        defer { isLoadingImpacts = false }
        
        var impacts: [String: ByeWeekImpact] = [:]
        
        for team in byeTeams {
            let impact = await analyzeByeWeekImpact(
                for: team.id,
                week: weekSelectionManager.selectedWeek,
                unifiedLeagueManager: unifiedLeagueManager,
                matchupsHubViewModel: matchupsHubViewModel
            )
            
            impacts[team.id] = impact
        }
        
        byeWeekImpacts = impacts
    }
    
    // MARK: - Bye Week Impact Analysis (inline to avoid .shared)
    
    private func analyzeByeWeekImpact(
        for teamCode: String,
        week: Int,
        unifiedLeagueManager: UnifiedLeagueManager,
        matchupsHubViewModel: MatchupsHubViewModel
    ) async -> ByeWeekImpact {
        
        var affectedPlayers: [AffectedPlayer] = []
        let normalizedTeamCode = normalizeTeamCode(teamCode)
        
        // Use the already-loaded matchups from MatchupsHubViewModel
        let allMatchups = matchupsHubViewModel.myMatchups
        
        DebugPrint(mode: .weekCheck, "🔍 Analyzing bye impact for \(teamCode) across \(allMatchups.count) matchups")
        
        for matchup in allMatchups {
            // 🔥 SKIP: Eliminated chopped leagues - they don't matter anymore!
            if matchup.isMyManagerEliminated {
                DebugPrint(mode: .weekCheck, "   ⏭️ Skipping \(matchup.league.league.name) - already eliminated")
                continue
            }
            
            // Get my team's starting lineup
            guard let myTeam = matchup.myTeam else { continue }
            
            let leagueName = matchup.league.league.name
            
            // Filter to starting lineup players only
            let starters = myTeam.roster.filter { $0.isStarter }
            
            // Find players on the bye team
            for player in starters {
                guard let playerTeam = player.team, !playerTeam.isEmpty else {
                    continue
                }
                
                if normalizeTeamCode(playerTeam) == normalizedTeamCode {
                    let affectedPlayer = AffectedPlayer(
                        playerName: player.fullName,
                        position: player.position,
                        nflTeam: playerTeam,
                        leagueName: leagueName,
                        fantasyTeamName: myTeam.name,
                        currentPoints: player.currentPoints,
                        projectedPoints: player.projectedPoints,
                        sleeperID: player.sleeperID
                    )
                    
                    affectedPlayers.append(affectedPlayer)
                    
                    DebugPrint(mode: .weekCheck, "   ⚠️ Found affected player: \(player.fullName) in \(leagueName)")
                }
            }
        }
        
        DebugPrint(mode: .weekCheck, "✅ Total affected players for \(teamCode): \(affectedPlayers.count)")
        
        return ByeWeekImpact(
            teamCode: teamCode,
            affectedPlayers: affectedPlayers
        )
    }
    
    private func normalizeTeamCode(_ teamCode: String) -> String {
        let normalized = teamCode.uppercased().trimmingCharacters(in: .whitespaces)
        
        // Handle special cases
        switch normalized {
        case "WAS", "WSH": return "WSH"  // Washington team code variations
        default: return normalized
        }
    }
}

// MARK: -> Schedule Bye Team Cell
struct ScheduleByeTeamCell: View {
    let team: NFLTeam
    let byeWeekImpact: ByeWeekImpact?
    let isLoadingImpacts: Bool
    let standingsService: NFLStandingsService
    let teamAssetManager: TeamAssetManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            // Only fire action if not loading and has problem
            if !isLoadingImpacts, let impact = byeWeekImpact, impact.hasProblem {
                onTap()
            }
        }) {
            VStack(spacing: 8) {
                // Team logo with badge overlay
                ZStack(alignment: .topTrailing) {
                    teamAssetManager.logoOrFallback(for: team.id)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(team.primaryColor.opacity(0.15))
                                .frame(width: 60, height: 60)
                        )
                        .grayscale(standingsService.isTeamEliminated(for: team.id) ? 1.0 : 0.0)
                        .opacity(standingsService.isTeamEliminated(for: team.id) ? 0.4 : 1.0)
                    
                    // Badge: Checkmark or X (only show after loading completes)
                    if !isLoadingImpacts, let impact = byeWeekImpact {
                        if impact.hasProblem {
                            // RED X - Problem!
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gpRedPink)
                                .background(
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                )
                                .offset(x: 4, y: -4)
                        } else {
                            // GREEN CHECKMARK - All clear!
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.green)
                                .background(
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                )
                                .offset(x: 4, y: -4)
                        }
                    }
                    
                    // 🔥 NEW: Show elimination skull badge
                    if standingsService.isTeamEliminated(for: team.id) {
                        Image(systemName: "skull.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 20, height: 20)
                            )
                            .offset(x: -24, y: -4)
                    }
                }
                
                // Team name
                Text(team.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(standingsService.isTeamEliminated(for: team.id) ? .white.opacity(0.4) : .white.opacity(0.8))
                
                // 🔥 NEW: Show "ELIMINATED" text if eliminated
                if standingsService.isTeamEliminated(for: team.id) {
                    Text("ELIMINATED")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        // 🔥 FIX: Keep full color even when disabled - only dim while loading
        .opacity(isLoadingImpacts ? 0.5 : 1.0)
        .allowsHitTesting(!isLoadingImpacts && byeWeekImpact?.hasProblem == true)
    }
    
    // MARK: - Helpers
    
    private var borderColor: Color {
        if isLoadingImpacts {
            return team.primaryColor.opacity(0.3)
        }
        
        // 🔥 NEW: Gray border for eliminated teams
        if standingsService.isTeamEliminated(for: team.id) {
            return Color.gray.opacity(0.3)
        }
        
        guard let impact = byeWeekImpact else {
            return team.primaryColor.opacity(0.3)
        }
        
        return impact.hasProblem ? Color.gpRedPink.opacity(0.5) : Color.green.opacity(0.3)
    }
    
    private var borderWidth: CGFloat {
        if isLoadingImpacts {
            return 1
        }
        
        guard let impact = byeWeekImpact else {
            return 1
        }
        
        return impact.hasProblem ? 2 : 1
    }
}

// MARK: - Identifiable wrapper for sheet presentation
struct ByeWeekImpactItem: Identifiable {
    let id = UUID()
    let impact: ByeWeekImpact
    let team: NFLTeam
}

// 🔥 PHASE 4: Preview disabled during DI migration
/*
#Preview {
    @Previewable @State var isPresented = true
    
    let sampleTeams = ["BUF", "MIA", "NYJ", "NE"].map { team in
        ByeWeekTeam(
            abbreviation: team,
            name: "Team \(team)",
            logo: nil,
            impactedPlayers: []
        )
    }
    
    let espnCredentials = ESPNCredentialsManager()
    let sleeperAPIClient = SleeperAPIClient()
    ...
}
*/

#Preview("Schedule Bye Week Section") {
    let sampleTeams = [
        NFLTeam.team(for: "KC")!,
        NFLTeam.team(for: "BUF")!,
        NFLTeam.team(for: "SF")!,
        NFLTeam.team(for: "PHI")!,
        NFLTeam.team(for: "DAL")!,
        NFLTeam.team(for: "MIA")!
    ]
    
    let espnCredentials = ESPNCredentialsManager()
    let sleeperAPIClient = SleeperAPIClient()
    let sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient)
    let playerDirectory = PlayerDirectoryStore(apiClient: sleeperAPIClient)
    let nflGameDataService = NFLGameDataService(
        weekSelectionManager: WeekSelectionManager(nflWeekService: NFLWeekService(apiClient: sleeperAPIClient)),
        appLifecycleManager: AppLifecycleManager.shared
    )
    let gameStatusService = GameStatusService(nflGameDataService: nflGameDataService)
    let nflWeekService = NFLWeekService(apiClient: sleeperAPIClient)
    let weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService)
    let seasonYearManager = SeasonYearManager()
    let playerStatsCache = PlayerStatsCache()
    let sharedStatsService = SharedStatsService(
        weekSelectionManager: weekSelectionManager,
        seasonYearManager: seasonYearManager,
        playerStatsCache: playerStatsCache
    )
    let standingsService = NFLStandingsService()
    let teamAssetManager = TeamAssetManager()
    
    let espnClient = ESPNAPIClient(credentialsManager: espnCredentials)
    let unifiedLeagueManager = UnifiedLeagueManager(
        sleeperClient: sleeperAPIClient,
        espnClient: espnClient,
        espnCredentials: espnCredentials
    )
    
    let matchupDataStore = MatchupDataStore(
        unifiedLeagueManager: unifiedLeagueManager,
        sharedStatsService: sharedStatsService,
        gameStatusService: gameStatusService,
        weekSelectionManager: weekSelectionManager,
        playoffEliminationService: PlayoffEliminationService(sleeperClient: sleeperAPIClient, espnClient: espnClient)
    )
    
    let choppedLeagueService = ChoppedLeagueService(
        sleeperClient: sleeperAPIClient,
        playerDirectory: playerDirectory,
        gameStatusService: gameStatusService,
        sharedStatsService: sharedStatsService,
        weekSelectionManager: weekSelectionManager,
        seasonYearManager: seasonYearManager,
        sleeperCredentials: sleeperCredentials
    )
    
    let matchupsHub = MatchupsHubViewModel(
        espnCredentials: espnCredentials,
        sleeperCredentials: sleeperCredentials,
        playerDirectory: playerDirectory,
        gameStatusService: gameStatusService,
        sharedStatsService: sharedStatsService,
        matchupDataStore: matchupDataStore,
        gameDataService: nflGameDataService,
        unifiedLeagueManager: unifiedLeagueManager,
        playoffEliminationService: PlayoffEliminationService(sleeperClient: sleeperAPIClient, espnClient: espnClient),
        choppedLeagueService: choppedLeagueService
    )
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScheduleByeWeekSection(
            byeTeams: sampleTeams,
            unifiedLeagueManager: unifiedLeagueManager,
            matchupsHubViewModel: matchupsHub,
            weekSelectionManager: weekSelectionManager,
            standingsService: standingsService,
            teamAssetManager: teamAssetManager
        )
    }
    .preferredColorScheme(.dark)
}