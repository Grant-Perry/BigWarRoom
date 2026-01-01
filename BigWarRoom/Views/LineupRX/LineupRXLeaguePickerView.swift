//
//  LineupRXLeaguePickerView.swift
//  BigWarRoom
//
//  💊 League picker for Lineup RX - accessed from More... page
//

import SwiftUI

struct LineupRXLeaguePickerView: View {
    @Environment(MatchupsHubViewModel.self) private var matchupsHub
    
    var body: some View {
        ZStack {
            // Background
            Image("BG7")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.35)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("💊 Lineup RX")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                Text("Select a league to optimize")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                // League list
                if matchupsHub.myMatchups.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(activeMatchups) { matchup in
                                NavigationLink(destination: LineupRXView(matchup: matchup)) {
                                    LeagueRowView(matchup: matchup)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Filter out eliminated chopped leagues
    private var activeMatchups: [UnifiedMatchup] {
        matchupsHub.myMatchups.filter { !$0.isMyManagerEliminated }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sportscourt")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Active Leagues")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Add leagues in Settings to use Lineup RX")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

// MARK: - League Row View
private struct LeagueRowView: View {
    let matchup: UnifiedMatchup
    
    var body: some View {
        HStack(spacing: 16) {
            // League avatar/icon
            ZStack {
                Circle()
                    .fill(matchup.isChoppedLeague ? Color.orange.opacity(0.15) : Color.gpGreen.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                if let avatarURL = matchup.league.league.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        leagueIcon
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    leagueIcon
                }
            }
            
            // League info
            VStack(alignment: .leading, spacing: 4) {
                Text(matchup.league.league.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // League type badge
                    Text(matchup.isChoppedLeague ? "ELIMINATION" : "H2H")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(matchup.isChoppedLeague ? .orange : .gpGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill((matchup.isChoppedLeague ? Color.orange : Color.gpGreen).opacity(0.2))
                        )
                    
                    // My score
                    if let score = matchup.myTeam?.currentScore {
                        Text(String(format: "%.1f pts", score))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Pills icon
            Image(systemName: "pills.fill")
                .font(.system(size: 20))
                .foregroundColor(.gpGreen)
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var leagueIcon: some View {
        Image(systemName: matchup.isChoppedLeague ? "flame.fill" : "sportscourt.fill")
            .font(.system(size: 22))
            .foregroundColor(matchup.isChoppedLeague ? .orange : .gpGreen)
    }
}

#Preview {
    let espnCredentials = ESPNCredentialsManager.shared
    let sleeperCredentials = SleeperCredentialsManager.shared
    let playerDirectory = PlayerDirectoryStore.shared
    let gameStatusService = GameStatusService.shared
    let sharedStatsService = SharedStatsService.shared
    let weekSelectionManager = WeekSelectionManager.shared
    let nflGameDataService = NFLGameDataService.shared
    
    let sleeperClient = SleeperAPIClient()
    let espnClient = ESPNAPIClient(credentialsManager: espnCredentials)
    let unifiedLeagueManager = UnifiedLeagueManager(
        sleeperClient: sleeperClient,
        espnClient: espnClient,
        espnCredentials: espnCredentials
    )
    
    let matchupDataStore = MatchupDataStore(
        unifiedLeagueManager: unifiedLeagueManager,
        sharedStatsService: sharedStatsService,
        gameStatusService: gameStatusService,
        weekSelectionManager: weekSelectionManager,
        playoffEliminationService: PlayoffEliminationService(sleeperClient: sleeperClient, espnClient: espnClient)  // 🔥 FIX: Add service
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
        playoffEliminationService: PlayoffEliminationService(sleeperClient: sleeperClient, espnClient: espnClient)  // 🔥 FIX: Add service
    )
    
    NavigationView {
        LineupRXLeaguePickerView()
            .environment(matchupsHub)
    }
    .preferredColorScheme(.dark)
}