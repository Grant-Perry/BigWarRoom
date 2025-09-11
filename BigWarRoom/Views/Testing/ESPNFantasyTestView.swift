//
//  ESPNFantasyTestView.swift
//  BigWarRoom
//
//  Test view to verify ESPN Fantasy integration with ALL MATCHUPS displayed
//

import SwiftUI

struct ESPNFantasyTestView: View {
    @StateObject private var espnViewModel = ESPNFantasyViewModel()
    @StateObject private var weekManager = WeekSelectionManager.shared
    @ObservedObject private var nflWeekService = NFLWeekService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Fixed Header
                headerSection
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Controls
                        controlsSection
                        
                        Divider()
                        
                        // Results
                        if espnViewModel.isLoading {
                            loadingView
                        } else if let errorMessage = espnViewModel.errorMessage {
                            errorView(errorMessage)
                        } else if let model = espnViewModel.espnFantasyModel {
                            // 🔥 SUCCESS! Show ALL ESPN matchups
                            dataView(model)
                        } else {
                            emptyStateView
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .onAppear {
                // Set initial league if available
                if espnViewModel.selectedLeagueID.isEmpty,
                   let firstLeague = AppConstants.ESPNLeagueID.first {
                    espnViewModel.selectedLeagueID = firstLeague
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("🏈 ESPN Fantasy Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Current NFL Week indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NFL Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        if nflWeekService.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "calendar")
                                .foregroundColor(.gpGreen)
                        }
                        
                        Text("\(nflWeekService.currentWeek)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.gpGreen)
                    }
                }
            }
            
            Text("SleepThis Integration • Using REAL Sleeper API Week")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // League Selection
            if !espnViewModel.availableLeagues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select League")
                        .font(.headline)
                    
                    Picker("League", selection: $espnViewModel.selectedLeagueID) {
                        ForEach(espnViewModel.availableLeagues, id: \.id) { league in
                            Text(league.name).tag(league.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: espnViewModel.selectedLeagueID) { _, newValue in
                        espnViewModel.selectLeague(newValue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Week and Year Selection
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Week")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Week", selection: $weekManager.selectedWeek) {
                        ForEach(1...18, id: \.self) { week in
                            HStack {
                                Text("Week \(week)")
                                if week == nflWeekService.currentWeek {
                                    Text("(Current)")
                                        .foregroundColor(.gpGreen)
                                }
                            }.tag(week)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Year")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Year", selection: $espnViewModel.selectedYear) {
                        ForEach(["2023", "2024", "2025"], id: \.self) { year in
                            HStack {
                                Text(year)
                                if year == nflWeekService.currentYear {
                                    Text("(Current)")
                                        .foregroundColor(.gpGreen)
                                }
                            }.tag(year)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: espnViewModel.selectedYear) { _, newValue in
                        espnViewModel.selectYear(newValue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Fetch Button
            Button("🚀 Fetch ESPN Data") {
                espnViewModel.fetchFantasyData()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading ESPN Fantasy Data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Error View
    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemRed).opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Data")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Tap 'Fetch ESPN Data' to load fantasy information using SleepThis logic")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Individual Matchup Card
    private func matchupCard(_ matchup: ESPNFantasyMatchupModel) -> some View {
        // FIXED: Handle optional away team (bye weeks)
        guard let awayTeamEntry = matchup.away,
              let awayTeam = espnViewModel.getTeam(for: awayTeamEntry.teamId),
              let homeTeam = espnViewModel.getTeam(for: matchup.home.teamId) else {
            return AnyView(EmptyView())
        }
        
        let awayScore = awayTeam.activeRosterScore(for: weekManager.selectedWeek)
        let homeScore = homeTeam.activeRosterScore(for: weekManager.selectedWeek)
        let awayWinning = awayScore > homeScore
        let homeWinning = homeScore > awayScore
        let scoreDiff = abs(awayScore - homeScore)
        
        return AnyView(
            VStack(spacing: 0) {
                // Matchup header
                HStack {
                    Text("Matchup \(matchup.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Diff: \(String(format: "%.2f", scoreDiff))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Main matchup display
                HStack(spacing: 0) {
                    // Away Team
                    VStack(spacing: 8) {
                        // Team name
                        Text(awayTeam.name ?? "Team \(awayTeam.id)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(awayWinning ? .gpGreen : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        // Record if available
                        if let record = awayTeam.record {
                            Text("\(record.overall.wins)-\(record.overall.losses)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Score
                        Text(String(format: "%.2f", awayScore))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(awayWinning ? .gpGreen : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5).opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(awayWinning ? Color.gpGreen : Color.clear, lineWidth: 2)
                            )
                    )
                    
                    // VS Section
                    VStack(spacing: 4) {
                        Text("VS")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Week \(weekManager.selectedWeek)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 50)
                    
                    // Home Team
                    VStack(spacing: 8) {
                        // Team name
                        Text(homeTeam.name ?? "Team \(homeTeam.id)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(homeWinning ? .gpGreen : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        // Record if available
                        if let record = homeTeam.record {
                            Text("\(record.overall.wins)-\(record.overall.losses)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Score
                        Text(String(format: "%.2f", homeScore))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(homeWinning ? .gpGreen : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5).opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(homeWinning ? Color.gpGreen : Color.clear, lineWidth: 2)
                            )
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
                // Roster info (collapsed by default)
                DisclosureGroup("View Rosters") {
                    VStack(spacing: 12) {
                        // Active Roster counts
                        HStack {
                            VStack {
                                let awayActive = awayTeam.activePlayers(for: weekManager.selectedWeek)
                                Text("\(awayActive.count)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gpGreen)
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("ROSTERS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            VStack {
                                let homeActive = homeTeam.activePlayers(for: weekManager.selectedWeek)
                                Text("\(homeActive.count)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gpGreen)
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Bench counts
                        HStack {
                            VStack {
                                let awayBench = awayTeam.benchPlayers(for: weekManager.selectedWeek)
                                let benchScore = awayBench.reduce(0.0) { $0 + $1.getScore(for: weekManager.selectedWeek) }
                                Text("\(awayBench.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Bench (\(String(format: "%.1f", benchScore)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack {
                                let homeBench = homeTeam.benchPlayers(for: weekManager.selectedWeek)
                                let benchScore = homeBench.reduce(0.0) { $0 + $1.getScore(for: weekManager.selectedWeek) }
                                Text("\(homeBench.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Bench (\(String(format: "%.1f", benchScore)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5).opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
        )
    }
    
    // MARK: - Data View
    private func dataView(_ model: ESPNFantasyLeagueModel) -> some View {
        let weekMatchups = espnViewModel.getMatchups(for: weekManager.selectedWeek)
        
        return VStack(alignment: .leading, spacing: 16) {
            // League Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("📊 League Summary")
                    .font(.headline)
                    .fontWeight(.bold)
                
                HStack(spacing: 30) {
                    VStack {
                        Text("\(model.teams.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.gpGreen)
                        Text("Teams")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(weekMatchups.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Matchups")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        let totalGamesPlayed = model.teams.compactMap { $0.roster?.entries.count }.reduce(0, +)
                        Text("\(totalGamesPlayed)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Total Players")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemBlue).opacity(0.1))
            .cornerRadius(12)
            
            // ALL MATCHUPS LIST 🔥
            Text("🏈 Week \(weekManager.selectedWeek) Matchups")
                .font(.title2)
                .fontWeight(.bold)
            
            if weekMatchups.isEmpty {
                Text("No matchups available for this week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(weekMatchups, id: \.id) { matchup in
                        matchupCard(matchup)
                    }
                }
            }
        }
    }
}

#Preview {
    ESPNFantasyTestView()
}