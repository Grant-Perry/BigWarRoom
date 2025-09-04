//
//  FantasyMatchupListView.swift  
//  BigWarRoom
//
//  Fantasy matchup list with league picker, week picker, and matchup cards
//
// MARK: -> Fantasy Matchup List View

import SwiftUI

struct FantasyMatchupListView: View {
    let draftRoomViewModel: DraftRoomViewModel  // Accept the shared view model
    @StateObject private var viewModel = FantasyViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Connection status header (always show)
                    connectionStatusHeader
                    
                    // Matchups content
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.matchups.isEmpty {
                        emptyStateView
                    } else {
                        matchupsList
                    }
                }
            }
            .navigationTitle(viewModel.selectedLeague?.league.name ?? "Fantasy")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: 
                Button("Week \(viewModel.selectedWeek)") {
                    viewModel.presentWeekSelector()
                }
                .font(.headline)
                .foregroundColor(.blue)
            )
            .preferredColorScheme(.dark)
            .sheet(isPresented: $viewModel.showWeekSelector) {
                ESPNDraftPickSelectionSheet.forFantasy(
                    leagueName: viewModel.selectedLeague?.league.name ?? "Fantasy League",
                    currentWeek: viewModel.currentNFLWeek,
                    selectedWeek: $viewModel.selectedWeek,
                    onConfirm: { week in
                        viewModel.selectWeek(week)
                        viewModel.dismissWeekSelector()
                    },
                    onCancel: {
                        viewModel.dismissWeekSelector()
                    }
                )
            }
            .task {
                await setupConnectedLeague()
            }
            .onAppear {
                // Pass the shared DraftRoomViewModel to FantasyViewModel
                viewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
            }
        }
    }
    
    // MARK: -> Connected League Setup
    /// Setup Fantasy to show only the connected league from War Room
    private func setupConnectedLeague() async {
        await viewModel.loadLeagues()
        
        // FIXED: Only use connected league from War Room - no switching allowed
        if let connectedLeagueWrapper = draftRoomViewModel.selectedLeagueWrapper {
            // xprint("🏈 Fantasy: Using connected league from War Room: '\(connectedLeagueWrapper.league.name)'")
            
            // Find matching league in Fantasy's available leagues
            if let matchingLeague = viewModel.availableLeagues.first(where: { 
                $0.league.leagueID == connectedLeagueWrapper.league.leagueID 
            }) {
                // xprint("🏈 Fantasy: Loading matchups for: '\(matchingLeague.league.name)'")
                viewModel.selectLeague(matchingLeague)
            } else {
                // xprint("🏈 Fantasy: Connected league not found in available leagues")
            }
        } else {
            // xprint("🏈 Fantasy: No connected league from War Room")
        }
    }
    
    // MARK: -> Connection Status Header
    private var connectionStatusHeader: some View {
        VStack(spacing: 12) {
            // Only show connection status in debug mode
            if AppConstants.debug {
                if let connectedLeague = draftRoomViewModel.selectedLeagueWrapper {
                    // Connected league info with auto-refresh toggle
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // Source logo
                            Group {
                                if connectedLeague.source == .sleeper {
                                    AppConstants.sleeperLogo
                                        .frame(width: 20, height: 20)
                                } else {
                                    AppConstants.espnLogo
                                        .frame(width: 20, height: 20)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundColor(.green)
                                        .font(.system(size: 12))
                                    
                                    Text("Connected to '\(connectedLeague.league.name)'")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                                
                                Text("From War Room • \(connectedLeague.source.displayName)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Auto-refresh toggle
                            Button(action: {
                                viewModel.toggleAutoRefresh()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(viewModel.autoRefresh ? .green : .secondary)
                                        .font(.system(size: 12))
                                    
                                    Text(viewModel.autoRefresh ? "ON" : "OFF")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(viewModel.autoRefresh ? .green : .secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                } else {
                    // No connection - prompt user (only in debug)
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            
                            Text("No League Connected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                        
                        Text("Go to War Room to connect to a league first")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                }
            }
            
            // DEBUG: ESPN Test Button (only in debug mode)
            if AppConstants.debug {
                NavigationLink(destination: ESPNFantasyTestView()) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.red)
                        
                        Text("🔥 ESPN Fantasy Test (SleepThis Integration)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: -> Content Views (unchanged)
    private var loadingView: some View {
        FantasyLoadingIndicator()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No matchups found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            if draftRoomViewModel.selectedLeagueWrapper != nil {
                Text("No matchups available for the current week")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connect to a league in War Room first")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var matchupsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Regular matchups
                ForEach(viewModel.matchups) { matchup in
                    NavigationLink(destination: FantasyMatchupDetailView(
                        matchup: matchup,
                        fantasyViewModel: viewModel,
                        leagueName: viewModel.selectedLeague?.league.name ?? "League"
                    )) {
                        FantasyMatchupCard(matchup: matchup)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Bye week teams section
                if !viewModel.byeWeekTeams.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Section header
                        HStack {
                            Image(systemName: "bed.double")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                            
                            Text("Bye Week")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Text("\(viewModel.byeWeekTeams.count) team\(viewModel.byeWeekTeams.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // Bye week teams
                        ForEach(viewModel.byeWeekTeams, id: \.id) { team in
                            ByeWeekCard(team: team, week: viewModel.selectedWeek)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: -> Fantasy Matchup Card
struct FantasyMatchupCard: View {
    let matchup: FantasyMatchup
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with week info
            HStack {
                Text("Week \(matchup.week)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(matchup.winProbabilityString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Main matchup content
            HStack(spacing: 0) {
                // Home team
                teamSection(
                    team: matchup.homeTeam,
                    score: matchup.homeTeam.currentScoreString,
                    isHome: true
                )
                
                // VS divider  
                VStack {
                    Text("VS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Week \(matchup.week)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(matchup.winProbabilityString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
                .frame(width: 60)
                
                // Away team
                teamSection(
                    team: matchup.awayTeam,
                    score: matchup.awayTeam.currentScoreString,
                    isHome: false
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func teamSection(team: FantasyTeam, score: String, isHome: Bool) -> some View {
        VStack(spacing: 8) {
            // Team avatar - Enhanced for ESPN teams
            Group {
                if let avatarURL = team.avatarURL {
                    // Sleeper leagues with real avatars
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            espnTeamAvatar(team: team)
                        case .empty:
                            espnTeamAvatar(team: team)
                        @unknown default:
                            espnTeamAvatar(team: team)
                        }
                    }
                } else {
                    // ESPN leagues with custom team avatars
                    espnTeamAvatar(team: team)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            // Team info
            VStack(spacing: 2) {
                Text(team.ownerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let record = team.record {
                    Text(record.displayString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Text("PF: \(team.record?.wins ?? 0)nd • PA: \(team.record?.losses ?? 0)nd")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Score
            Text(score)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isHome ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Custom ESPN team avatar with unique colors and better styling
    private func espnTeamAvatar(team: FantasyTeam) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        team.espnTeamColor,
                        team.espnTeamColor.opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(team.espnTeamColor.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                Text(team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            )
    }
}

// MARK: -> Bye Week Card
struct ByeWeekCard: View {
    let team: FantasyTeam
    let week: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Team avatar
            Group {
                if let avatarURL = team.avatarURL {
                    // Sleeper leagues with real avatars
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            espnTeamAvatar(team: team)
                        case .empty:
                            espnTeamAvatar(team: team)
                        @unknown default:
                            espnTeamAvatar(team: team)
                        }
                    }
                } else {
                    // ESPN leagues with custom team avatars
                    espnTeamAvatar(team: team)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .grayscale(0.5) // Make bye week avatars slightly faded
            
            // Team info
            VStack(alignment: .leading, spacing: 4) {
                Text(team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if let record = team.record {
                    Text(record.displayString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("No opponent this week")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Bye week indicator
            VStack(spacing: 4) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("BYE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("Week \(week)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            )
    }
    
    /// Custom ESPN team avatar (same as matchup card)
    private func espnTeamAvatar(team: FantasyTeam) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        team.espnTeamColor.opacity(0.6), // More faded for bye weeks
                        team.espnTeamColor.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(team.espnTeamColor.opacity(0.2), lineWidth: 2)
            )
            .overlay(
                Text(team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            )
    }
}