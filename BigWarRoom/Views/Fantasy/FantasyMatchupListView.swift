//
//  FantasyMatchupListView.swift  
//  BigWarRoom
//
//  Fantasy matchup list with league picker, week picker, and matchup cards
//
// MARK: -> Fantasy Matchup List View

import SwiftUI

struct FantasyMatchupListView: View {
    @StateObject private var viewModel = FantasyViewModel()
    @State private var showFilters = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter section
                    filterSection
                    
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
            .preferredColorScheme(.dark)
            .task {
                await viewModel.loadLeagues()
                if let firstLeague = viewModel.availableLeagues.first {
                    viewModel.selectLeague(firstLeague)
                }
            }
        }
    }
    
    // MARK: -> Filter Section
    private var filterSection: some View {
        VStack(spacing: 16) {
            // Hide/Show Filters Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showFilters.toggle()
                }
            }) {
                HStack {
                    Text("Hide Filters")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: showFilters ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            
            // Filters (collapsible)
            if showFilters {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    // League Picker
                    leaguePicker
                    
                    // Week Picker  
                    weekPicker
                    
                    // Year Picker
                    yearPicker
                    
                    // Auto Refresh Toggle
                    autoRefreshToggle
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.black)
    }
    
    // MARK: -> Filter Components
    private var leaguePicker: some View {
        Menu {
            ForEach(viewModel.availableLeagues, id: \.id) { league in
                Button(action: {
                    viewModel.selectLeague(league)
                }) {
                    HStack {
                        Text(league.league.name)
                        Spacer()
                        if viewModel.selectedLeague?.id == league.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                
                Text(viewModel.selectedLeague?.league.name ?? "Select League")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private var weekPicker: some View {
        Menu {
            ForEach(viewModel.availableWeeks, id: \.self) { week in
                Button("Week \(week)") {
                    viewModel.selectWeek(week)
                }
            }
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                
                Text("Week \(viewModel.selectedWeek)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private var yearPicker: some View {
        Menu {
            ForEach(viewModel.availableYears, id: \.self) { year in
                Button(year) {
                    viewModel.selectYear(year)
                }
            }
        } label: {
            HStack {
                Image(systemName: "calendar.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                
                Text("Year: \(viewModel.selectedYear)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private var autoRefreshToggle: some View {
        Button(action: {
            viewModel.toggleAutoRefresh()
        }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                
                Text("Auto Refresh: \(viewModel.autoRefresh ? "On" : "Off")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    // MARK: -> Content Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading matchups...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
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
            
            Text("Select a league to view matchups")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var matchupsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
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