//
//  NFLPlayoffBracketView.swift
//  BigWarRoom
//
//  ESPN-style playoff bracket with blue gradient and bracket lines
//

import SwiftUI

struct NFLPlayoffBracketView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TeamAssetManager.self) private var teamAssets
    @Environment(NFLStandingsService.self) private var standingsService
    @State private var bracketService: NFLPlayoffBracketService
    @State private var selectedSeason: Int
    
    // 🔥 FIX: Observe the year manager
    @State private var yearManager = SeasonYearManager.shared
    
    // Dependencies
    let weekSelectionManager: WeekSelectionManager
    let appLifecycleManager: AppLifecycleManager
    let fantasyViewModel: FantasyViewModel?
    
    init(
        weekSelectionManager: WeekSelectionManager,
        appLifecycleManager: AppLifecycleManager,
        fantasyViewModel: FantasyViewModel? = nil,
        initialSeason: Int? = nil
    ) {
        self.weekSelectionManager = weekSelectionManager
        self.appLifecycleManager = appLifecycleManager
        self.fantasyViewModel = fantasyViewModel
        
        let service = NFLPlayoffBracketService(
            weekSelectionManager: weekSelectionManager,
            appLifecycleManager: appLifecycleManager
        )
        _bracketService = State(initialValue: service)
        _selectedSeason = State(initialValue: initialSeason ?? AppConstants.currentSeasonYearInt)
    }
    
    var body: some View {
        ZStack {
            // Only apply the BG3 for the portrait view
            if verticalSizeClass != .compact {
                Image("BG3")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
            
            // --- ORIENTATION SWITCHER using verticalSizeClass ---
            if verticalSizeClass == .compact {
                // --- LANDSCAPE ---
                if let bracket = bracketService.currentBracket {
                    NFLLandscapeBracketView(bracket: bracket, playoffService: bracketService)
                } else {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        loadingView
                    }
                }
            } else {
                // --- PORTRAIT ---
                if bracketService.isLoading && bracketService.currentBracket == nil {
                    loadingView
                } else if let bracket = bracketService.currentBracket {
                    bracketContent(bracket)
                } else if let error = bracketService.errorMessage {
                    errorView(error)
                } else {
                    emptyView
                }
            }
        }
        .navigationTitle("")
        .preferredColorScheme(.dark)
        .task {
            await loadBracket()
        }
        .onChange(of: selectedSeason) { _, newSeason in
            Task {
                // 🔥 FIX: Fetch standings for new season
                standingsService.fetchStandings(forceRefresh: true, season: newSeason)
                await loadBracket(forceRefresh: true)
            }
        }
        // 🔥 NEW: Watch for year changes from SeasonYearManager
        .onChange(of: yearManager.selectedYear) { _, newYear in
            if let year = Int(newYear), year != selectedSeason {
                selectedSeason = year
            }
        }
        .onAppear {
            // 🔥 FIX: Sync with year manager on appear
            if let year = Int(yearManager.selectedYear), year != selectedSeason {
                selectedSeason = year
            }
            // Fetch standings for selected season on appear
            standingsService.fetchStandings(season: selectedSeason)
        }
        .onDisappear {
            // Stop live updates when view disappears to prevent crashes
            bracketService.stopLiveUpdates()
        }
    }
    
    // MARK: - Bracket Content
    
    @ViewBuilder
    private func bracketContent(_ bracket: PlayoffBracket) -> some View {
        let currentYear = Int(SeasonYearManager.shared.selectedYear) ?? AppConstants.currentSeasonYearInt
        
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 0) { // Using a safe space value to prevent crash
                // Title - CENTERED with dynamic year (no comma formatting) - 🔥 ADD TOP PADDING
                VStack(spacing: 2) {
                    Text("CURRENT \(String(currentYear))")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .italic()
                    
                    Text("PLAYOFF PICTURE")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                        .italic()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)  // 🔥 Add padding to separate from week picker
                
                // Add this new view right below the header
                topSeedsView(bracket: bracket)
                
                // Side-by-side conferences
                HStack(alignment: .top, spacing: 30) {
                    // AFC Bracket
                    conferenceColumn(
                        conference: .afc,
                        bracket: bracket
                    )
                    
                    // NFC Bracket
                    conferenceColumn(
                        conference: .nfc,
                        bracket: bracket
                    )
                }
                .padding(.leading, 12)
                .padding(.trailing, 32)
                .padding(.bottom, 20)
                
                Spacer()
            }
            .scaleEffect(0.9)
            .frame(maxHeight: .infinity, alignment: .top)
        }
		.offset(x: -12, y: -50)
        .refreshable {
            await loadBracket(forceRefresh: true)
        }

    }
    
    // MARK: - Conference Column
    
    @ViewBuilder
    private func conferenceColumn(
        conference: PlayoffGame.Conference,
        bracket: PlayoffBracket
    ) -> some View {
        VStack(spacing: 6) {
            // Conference label - RESTORED custom font
            Text(conference.rawValue)
                .font(.custom("BebasNeue-Regular", size: 24))
                .foregroundColor(.white)
            
            // Get seeds and games
            let seeds = getSeedsForConference(bracket: bracket, conference: conference)
            let games = conference == .afc ? bracket.afcGames : bracket.nfcGames
            
            VStack(spacing: 0) {
                // 1 seed (bye)
                if let seed1 = seeds[1] {
                    teamCard(team: seed1, seed: 1)
                }
                
                Spacer().frame(height: 20)
                
                // 5 vs 4 matchup with bracket line
                if let seed5 = seeds[5], let seed4 = seeds[4] {
                    let game = findGame(team1: seed5, team2: seed4, in: games)
                    
                    VStack(spacing: 0) {
                        // Game day info at TOP
                        if let matchup = game {
                            gameDayHeader(matchup)
                        }
                        
                        HStack(spacing: 0) {
                            // Bracket connector line with opacity
                            BracketConnectorLine()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .frame(width: 20, height: 120)
                            
                            VStack(spacing: 20) {
                                teamCard(team: seed5, seed: 5)
                                teamCard(team: seed4, seed: 4)
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 24)
                
                // 6 vs 3 matchup with bracket line
                if let seed6 = seeds[6], let seed3 = seeds[3] {
                    let game = findGame(team1: seed6, team2: seed3, in: games)
                    
                    VStack(spacing: 0) {
                        // Game day info at TOP
                        if let matchup = game {
                            gameDayHeader(matchup)
                        }
                        
                        HStack(spacing: 0) {
                            // Bracket connector line with opacity
                            BracketConnectorLine()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .frame(width: 20, height: 120)
                            
                            VStack(spacing: 20) {
                                teamCard(team: seed6, seed: 6)
                                teamCard(team: seed3, seed: 3)
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 24)
                
                // 7 vs 2 matchup with bracket line
                if let seed7 = seeds[7], let seed2 = seeds[2] {
                    let game = findGame(team1: seed7, team2: seed2, in: games)
                    
                    VStack(spacing: 0) {
                        // Game day info at TOP
                        if let matchup = game {
                            gameDayHeader(matchup)
                        }
                        
                        HStack(spacing: 0) {
                            // Bracket connector line with opacity
                            BracketConnectorLine()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .frame(width: 20, height: 120)
                            
                            VStack(spacing: 20) {
                                teamCard(team: seed7, seed: 7)
                                teamCard(team: seed2, seed: 2)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Game Day Header
    
    @ViewBuilder
    private func gameDayHeader(_ game: PlayoffGame) -> some View {
        HStack(spacing: 4) {
            if game.isLive {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                
                Text(game.status.displayText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            } else if game.isCompleted {
                Text("FINAL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text(formatGameDate(game.gameDate))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Helper Methods
    
    private func formatGameDate(_ date: Date) -> String {
        // If game time is TBD (defaults to midnight), only show the date.
        if !shouldShowGameTime(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"  // "Saturday, Jan 10"
            return formatter.string(from: date)
        }
        
        // Otherwise, show date and time
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d • h:mm a"  // "Sat, Jan 10 • 4:30 PM"
        return formatter.string(from: date)
    }
    
    // MARK: - Team Card (ESPN Style with Centered Watermark Seed)
    
    @ViewBuilder
    private func teamCard(team: PlayoffTeam, seed: Int) -> some View {
        // Team card with centered watermark seed - EXACT size, NO padding
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 8)
                .fill(teamColor(for: team.abbreviation))
            
            // Watermark seed number (centered with x offset)
            SeedNumberView(seed: seed)
                .offset(x: -15)
            
            // Content layer
            HStack(spacing: 0) {
                // Team name
                Text(team.displayName.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
                
                // Team logo
                if let logoImage = teamAssets.logo(for: team.abbreviation) {
                   let logoSize: CGFloat = 90.0
                    logoImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)

                        .padding(.trailing, 6)
                } else {
                    // Fallback
                    Text(team.abbreviation)
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                }
            }
        }
        .frame(width: 180, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Views
    
    /// Displays a formatted seed number (e.g., #1) for watermarks
    private struct SeedNumberView: View {
        let seed: Int
        
        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                Text("#")
                    .font(.system(size: 35, weight: .black))
                Text("\(seed)")
                    .font(.system(size: 70, weight: .black))
            }
            .foregroundColor(.white.opacity(0.25))
        }
    }
    
    // MARK: - Helper Methods
    
    private func teamColor(for teamCode: String) -> Color {
        teamAssets.team(for: teamCode)?.primaryColor ?? Color.blue.opacity(0.6)
    }
    
    /// Check if we should show the game time (hide if it's 12:00 AM which is clearly wrong)
    private func shouldShowGameTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // If it's exactly midnight (12:00 AM), don't show time
        return !(hour == 0 && minute == 0)
    }
    
    private func getSeedsForConference(bracket: PlayoffBracket, conference: PlayoffGame.Conference) -> [Int: PlayoffTeam] {
        var seeds: [Int: PlayoffTeam] = [:]
        
        let games = conference == .afc ? bracket.afcGames : bracket.nfcGames
        
        // Extract all teams with their seeds
        for game in games {
            if let homeSeed = game.homeTeam.seed {
                seeds[homeSeed] = game.homeTeam
            }
            if let awaySeed = game.awayTeam.seed {
                seeds[awaySeed] = game.awayTeam
            }
        }
        
        return seeds
    }
    
    private func findGame(team1: PlayoffTeam, team2: PlayoffTeam, in games: [PlayoffGame]) -> PlayoffGame? {
        games.first { game in
            (game.homeTeam.abbreviation == team1.abbreviation && game.awayTeam.abbreviation == team2.abbreviation) ||
            (game.homeTeam.abbreviation == team2.abbreviation && game.awayTeam.abbreviation == team1.abbreviation)
        }
    }
    
    private func loadBracket(forceRefresh: Bool = false) async {
        bracketService.fetchPlayoffBracket(for: selectedSeason, forceRefresh: forceRefresh)
        
        if let bracket = bracketService.currentBracket, bracket.hasLiveGames {
            bracketService.startLiveUpdates(for: selectedSeason)
        }
    }
    
    // MARK: - Loading/Error Views
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading playoff bracket...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.white)
            
            Text("Unable to load bracket")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    await loadBracket(forceRefresh: true)
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.3, blue: 0.8))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundColor(.white)
            
            Text("No playoff data available")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Playoff bracket will appear once seeds are finalized.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Top Seeds View
    
    @ViewBuilder
    private func topSeedsView(bracket: PlayoffBracket) -> some View {
        if let afcSeed1 = bracket.afcSeed1, let nfcSeed1 = bracket.nfcSeed1 {
            VStack(spacing: 5) {
                Text("TOP SEEDS")
                    .font(.custom("BebasNeue-Regular", size: 20))
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    topSeedCard(team: afcSeed1, seed: 1)
                    topSeedCard(team: nfcSeed1, seed: 1)
                }
            }
            .padding(.vertical, 10)
        }
    }
    
    @ViewBuilder
    private func topSeedCard(team: PlayoffTeam, seed: Int) -> some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 8)
                .fill(teamColor(for: team.abbreviation))
            
            // Watermark seed number
            SeedNumberView(seed: seed)
                .offset(x: -15)

            HStack(spacing: 0) {
                // Team Name (forced two lines)
                Text(team.displayName.uppercased().replacingOccurrences(of: " ", with: "\n"))
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
                
                // Team logo
                if let logoImage = teamAssets.logo(for: team.abbreviation) {
                    let logoSize: CGFloat = 90.0
                    logoImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)
                        .padding(.trailing, 6)
                } else {
                    // Fallback
                    Text(team.abbreviation)
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                }
            }
        }
        .frame(width: 180, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Landscape Placeholder
    
    @ViewBuilder
    private var landscapePlaceholder: some View {
        VStack(spacing: 16) {
            if bracketService.isLoading {
                ProgressView().tint(.white)
                Text("Loading Bracket...")
                    .foregroundColor(.white)
            } else {
                Image(systemName: "rotate.device.left.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text("No Playoff Data Available")
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
    }
}

// MARK: - Bracket Connector Line Shape

/// Curved bracket line connecting two teams in a matchup
struct BracketConnectorLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let cardHeight: CGFloat = 50
        let spacing: CGFloat = 20
        
        // Calculate centers of the two cards
        let topCardCenterY = cardHeight / 2
        let bottomCardCenterY = cardHeight + spacing + (cardHeight / 2)
        
        let startX = rect.maxX // Start at right edge (will touch card)
        let curveOutX = rect.minX // Curve out to left edge
        
        // Start at right edge, center of top card
        path.move(to: CGPoint(x: startX, y: topCardCenterY))
        
        // Line out to the left
        path.addLine(to: CGPoint(x: curveOutX + 10, y: topCardCenterY))
        
        // Rounded corner at top
        path.addQuadCurve(
            to: CGPoint(x: curveOutX, y: topCardCenterY + 10),
            control: CGPoint(x: curveOutX, y: topCardCenterY)
        )
        
        // Vertical line connecting the two cards
        path.addLine(to: CGPoint(x: curveOutX, y: bottomCardCenterY - 10))
        
        // Rounded corner at bottom
        path.addQuadCurve(
            to: CGPoint(x: curveOutX + 10, y: bottomCardCenterY),
            control: CGPoint(x: curveOutX, y: bottomCardCenterY)
        )
        
        // Line back to card
        path.addLine(to: CGPoint(x: startX, y: bottomCardCenterY))
        
        return path
    }
}

// MARK: - Preview

#Preview("NFL Playoff Bracket") {
    // 1. Mock Dependencies
    let apiClient = SleeperAPIClient() // Dummy client
    let weekService = NFLWeekService(apiClient: apiClient)
    let weekManager = WeekSelectionManager(nflWeekService: weekService)
    
    // Set week to a playoff week for the preview
    weekManager.selectedWeek = 19
    
    let appLifecycleManager = AppLifecycleManager.shared
    let teamAssetManager = TeamAssetManager()

    // 2. Mock View Instantiation
    return ZStack {
        // Use a dark background similar to the app's theme
        Color.black.opacity(0.8).ignoresSafeArea()
        
        NFLPlayoffBracketView(
            weekSelectionManager: weekManager,
            appLifecycleManager: appLifecycleManager,
            fantasyViewModel: nil,
            initialSeason: 2025
        )
        .environment(teamAssetManager)
    }
    .preferredColorScheme(.dark)
}