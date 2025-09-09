//
//  FantasyMatchupDetailView.swift
//  BigWarRoom
//
//  Detailed view for a specific fantasy matchup showing active rosters - EXACT SleepThis Match
//
// MARK: -> Fantasy Matchup Detail View

import SwiftUI

// MARK: -> NFLPlayer Model (Simplified) - MOVED TO TOP
struct NFLPlayer {
    let jersey: String
    let team: String
}

struct FantasyMatchupDetailView: View {
    let matchup: FantasyMatchup
    let leagueName: String
    var fantasyViewModel: FantasyViewModel? = nil
    @Environment(\.dismiss) private var dismiss // Use new dismiss instead of presentationMode
    
    // 🔥 NEW: Add shared instance to ensure stats are loaded early
    @ObservedObject private var livePlayersViewModel = AllLivePlayersViewModel.shared
    
    // Default initializer for backward compatibility
    init(matchup: FantasyMatchup, leagueName: String) {
        self.matchup = matchup
        self.leagueName = leagueName
        self.fantasyViewModel = nil
    }
    
    // Full initializer with FantasyViewModel
    init(matchup: FantasyMatchup, fantasyViewModel: FantasyViewModel, leagueName: String) {
        self.matchup = matchup
        self.leagueName = leagueName
        self.fantasyViewModel = fantasyViewModel
    }
    
    var body: some View {
        let awayTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 0) ?? matchup.awayTeam.currentScore ?? 0.0
        let homeTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 1) ?? matchup.homeTeam.currentScore ?? 0.0
        let awayTeamIsWinning = awayTeamScore > homeTeamScore
        let homeTeamIsWinning = homeTeamScore > awayTeamScore
        
        VStack(spacing: 0) {
            // Header with back button and countdown timer
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // League name and week info (preserve navigation context)
                VStack(spacing: 2) {
                    Text(leagueName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Week \(fantasyViewModel?.selectedWeek ?? matchup.week)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Circular countdown timer dial
                RefreshCountdownTimerView()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            HStack {
                Text("Matchup Details")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            FantasyDetailHeaderView(
                leagueName: leagueName,
                matchup: matchup,
                awayTeamIsWinning: awayTeamIsWinning,
                homeTeamIsWinning: homeTeamIsWinning,
                fantasyViewModel: fantasyViewModel
            )
            .frame(height: 140)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ScrollView {
                VStack(spacing: 16) {
                    if let viewModel = fantasyViewModel {
                        viewModel.activeRosterSection(matchup: matchup)
                        viewModel.benchSection(matchup: matchup)
                    } else {
                        // Fallback content when no view model is available
                        simplifiedRosterView
                    }
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true) // Ensure we use our custom back button
        .preferredColorScheme(.dark)
        .background(Color.black)
        
        .onAppear {
            // Force stats loading as soon as view appears
            Task {
                await livePlayersViewModel.forceLoadStats()
            }
        }
        .task {
            // Backup stats loading in task block
            if !livePlayersViewModel.statsLoaded {
                await livePlayersViewModel.loadAllPlayers()
            }
        }
    }
    
    // Simplified roster view for when no FantasyViewModel is available
    private var simplifiedRosterView: some View {
        VStack(spacing: 16) {
            // Home team roster
            VStack(alignment: .leading, spacing: 8) {
                Text("\(matchup.homeTeam.name) Roster")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(matchup.homeTeam.roster.filter { $0.isStarter }) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel ?? FantasyViewModel(),
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: false
                        )
                        .padding(.horizontal)
                    }
                }
            }
            
            // Away team roster  
            VStack(alignment: .leading, spacing: 8) {
                Text("\(matchup.awayTeam.name) Roster")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(matchup.awayTeam.roster.filter { $0.isStarter }) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel ?? FantasyViewModel(),
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: false
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: -> Refresh Countdown Timer View
struct RefreshCountdownTimerView: View {
    @State private var timeRemaining: TimeInterval = TimeInterval(AppConstants.MatchupRefresh)
    @State private var timer: Timer?
    @State private var glowIntensity: Double = 0.3
    
    // Color progression for the timer
    private var timerColor: Color {
        let progress = timeRemaining / TimeInterval(AppConstants.MatchupRefresh)
        
        if progress > 0.66 {
            return .green
        } else if progress > 0.33 {
            return .orange
        } else {
            return .red
        }
    }
    
    // Progress value for the circular progress
    private var progress: Double {
        return timeRemaining / TimeInterval(AppConstants.MatchupRefresh)
    }
    
    // Dynamic glow opacity based on time remaining - gets more intense as time runs out
    private var dynamicGlowOpacity: Double {
        let baseIntensity = glowIntensity
        let urgencyMultiplier = 1.0 + (1.0 - progress) * 2.0 // 1x to 3x intensity
        return baseIntensity * urgencyMultiplier
    }
    
    var body: some View {
        ZStack {
            // Subtle glow background layers - MUCH toned down
            ForEach(0..<2) { index in
                Circle()
                    .fill(timerColor.opacity(0.1))
                    .frame(width: 42 + CGFloat(index * 6), height: 42 + CGFloat(index * 6))
                    .blur(radius: CGFloat(2 + index * 2))
                    .opacity(0.3 * (1.0 - Double(index) * 0.3))
                    .animation(.easeInOut(duration: 0.5), value: timerColor)
            }
            
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2.5)
                .frame(width: 38, height: 38)
            
            // Center fill that matches the rotating circle color
            Circle()
                .fill(timerColor.opacity(0.2))
                .frame(width: 33, height: 33)
                .animation(.easeInOut(duration: 0.3), value: timerColor)
            
            // Progress circle with color animation
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [timerColor, timerColor.opacity(0.6)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Time remaining text
            Text(String(format: "%.0f", timeRemaining))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
                .animation(.easeInOut(duration: 0.3), value: timerColor)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        // Reset to full time when view appears
        timeRemaining = TimeInterval(AppConstants.MatchupRefresh)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Reset timer when it reaches 0 (next refresh cycle)
                timeRemaining = TimeInterval(AppConstants.MatchupRefresh)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: -> Fantasy Detail Header View
struct FantasyDetailHeaderView: View {
    let leagueName: String
    let matchup: FantasyMatchup
    let awayTeamIsWinning: Bool
    let homeTeamIsWinning: Bool
    let fantasyViewModel: FantasyViewModel?
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.clear, .purple.opacity(0.2)]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 80)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
            
            VStack(spacing: 4) {
                Text(leagueName)
                    .font(.system(size: 14, weight: .medium)) // Made slightly larger
                    .foregroundColor(.gray)
                    .padding(.top, 4)
                
                HStack(spacing: 16) {
                    // Away team (left side)
                    FantasyManagerDetails(
                        managerName: matchup.awayTeam.ownerName,
                        managerRecord: fantasyViewModel?.getManagerRecord(managerID: matchup.awayTeam.id) ?? "0-0",
                        score: matchup.awayTeam.currentScore ?? 0.0,
                        isWinning: awayTeamIsWinning,
                        avatarURL: matchup.awayTeam.avatarURL,
                        fantasyViewModel: fantasyViewModel,
                        rosterID: matchup.awayTeam.rosterID,
                        selectedYear: Int(fantasyViewModel?.selectedYear ?? "2024") ?? 2024
                    )
                    
                    VStack(spacing: 2) {
                        Text("VS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        Text("Week \(fantasyViewModel?.selectedWeek ?? matchup.week)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Text(fantasyViewModel?.scoreDifferenceText(matchup: matchup) ?? "")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.2))
                            )
                    }
                    .padding(.vertical, 2)
                    
                    // Home team (right side)
                    FantasyManagerDetails(
                        managerName: matchup.homeTeam.ownerName,
                        managerRecord: fantasyViewModel?.getManagerRecord(managerID: matchup.homeTeam.id) ?? "0-0",
                        score: matchup.homeTeam.currentScore ?? 0.0,
                        isWinning: homeTeamIsWinning,
                        avatarURL: matchup.homeTeam.avatarURL,
                        fantasyViewModel: fantasyViewModel,
                        rosterID: matchup.homeTeam.rosterID,
                        selectedYear: Int(fantasyViewModel?.selectedYear ?? "2024") ?? 2024
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: -> Fantasy Manager Details
struct FantasyManagerDetails: View {
    let managerName: String
    let managerRecord: String
    let score: Double
    let isWinning: Bool
    let avatarURL: URL?
    var fantasyViewModel: FantasyViewModel? = nil
    var rosterID: Int? = nil
    let selectedYear: Int
    
    @State private var showStatsPopup = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Avatar section
            ZStack {
                if let url = avatarURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                }
                
                if isWinning {
                    Circle()
                        .strokeBorder(Color.gpGreen, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            
            // Manager name
            Text(managerName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Record
            Text(managerRecord)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            
            // Score with winning color
            Text(String(format: "%.2f", score))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isWinning ? .gpGreen : .red)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: -> Fantasy Player Card (FIXED for ESPN players like SleepThis)
struct FantasyPlayerCard: View {
    let player: FantasyPlayer
    let fantasyViewModel: FantasyViewModel
    let matchup: FantasyMatchup?
    let teamIndex: Int?
    let isBench: Bool
    
    @State private var teamColor: Color = .gray
    @State private var nflPlayer: NFLPlayer? // 
    @State private var glowIntensity: Double = 0.0
    @StateObject private var gameViewModel = NFLGameMatchupViewModel()
    @State private var currentWeek: Int = NFLWeekService.shared.currentWeek
    @StateObject private var nflWeekService = NFLWeekService.shared
    
    @State private var showingPlayerDetail = false
    @StateObject private var playerDirectory = PlayerDirectoryStore.shared
    // 🔥 FIXED: Use shared stats instead of loading individually
    @ObservedObject private var livePlayersViewModel = AllLivePlayersViewModel.shared
    
    // 🔥 NEW: Add explicit state tracking for debugging
    @State private var hasAttemptedStatsLoad = false
    @State private var debugStatsStatus = "Not Started"

    private var positionalRanking: String {
        guard let matchup = matchup, let teamIndex = teamIndex else {
            return player.position.uppercased()
        }
        return fantasyViewModel.getPositionalRanking(for: player, in: matchup, teamIndex: teamIndex, isBench: isBench)
    }
    
    private var isPlayerLive: Bool {
        return player.isLive
    }
    
    private var borderColors: [Color] {
        if isPlayerLive {
            return [.gpGreen, .gpGreen.opacity(0.8), .cyan.opacity(0.6), .gpGreen.opacity(0.9), .gpGreen]
        } else {
            return [teamColor]
        }
    }
    
    private var borderWidth: CGFloat {
        if isPlayerLive {
            return 6
        } else {
            return 2
        }
    }
    
    private var borderOpacity: Double {
        if isPlayerLive {
            return max(0.8, glowIntensity * 0.9 + 0.3)
        } else {
            return 0.7
        }
    }
    
    private var shadowColor: Color {
        if isPlayerLive {
            return .gpGreen.opacity(0.8)
        } else {
            return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        if isPlayerLive {
            return 15
        } else {
            return 0
        }
    }

    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                // Background jersey number, pushed to top-trailing
                VStack {
                    HStack {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            Text(nflPlayer?.jersey ?? player.jerseyNumber ?? "")
                                .font(.system(size: 90, weight: .black))
                                .italic()
                                .foregroundColor(teamColor)
                                .opacity(0.55) // 🔥 MORE VISIBLE: Was 0.25, now 0.4
                                .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                        }
                    }
                    .padding(.trailing, 8)
                    Spacer()
                }
                
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [teamColor, .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if let team = player.team, let obj = NFLTeam.team(for: team) {
                    if let image = UIImage(named: obj.logoAssetName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .offset(x: 20, y: -4)
                            .opacity(isPlayerLive ? 0.6 : 0.35)
                            .shadow(color: obj.primaryColor.opacity(0.5), radius: 10, x: 0, y: 0)
                    } else {
                        AsyncImage(url: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                Image(systemName: "sportscourt.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 80, height: 80)
                        .offset(x: 20, y: -4)
                        .opacity(isPlayerLive ? 0.6 : 0.35)
                        .shadow(color: teamColor.opacity(0.5), radius: 10, x: 0, y: 0)
                    }
                }
                
                HStack(spacing: 12) {
                    AsyncImage(url: player.headshotURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 95, height: 95)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 95, height: 95)
                                .clipped()
                                .opacity(isPlayerLive ? 1.0 : 0.85)
                        case .failure:
                            if let espnURL = player.espnHeadshotURL {
                                AsyncImage(url: espnURL) { phase2 in
                                    switch phase2 {
                                    case .success(let image2):
                                        image2
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 95, height: 95)
                                            .clipped()
                                            .opacity(isPlayerLive ? 1.0 : 0.85)
                                    default:
                                        ZStack {
                                            Circle()
                                                .fill(teamColor.opacity(0.8))
                                                .frame(width: 95, height: 95)
                                            
                                            Text(player.shortName.prefix(2))
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .opacity(isPlayerLive ? 1.0 : 0.85)
                                    }
                                }
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(teamColor.opacity(0.8))
                                        .frame(width: 95, height: 95)
                                    
                                    Text(player.shortName.prefix(2))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .opacity(isPlayerLive ? 1.0 : 0.85)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .offset(x: -20, y: -8)
                    .zIndex(2)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Spacer()
                        
                        // 🔥 RESTORED: Original score positioning
                        HStack(alignment: .bottom, spacing: 4) {
                            Spacer()
                            Text(player.currentPointsString)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .scaleEffect(isPlayerLive ? (glowIntensity > 0.5 ? 1.15 : 1.0) : 1.0)
                                .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
                        }
                        .padding(.bottom, 30) // 🔥 ADJUSTED: More space for stats
                        .padding(.trailing, 12)
                    }
                    .zIndex(3)
                }
                
                // 🔥 FIXED: RIGHT JUSTIFIED player name and position - ALL THE WAY RIGHT
                HStack {
                    Spacer() // 🔥 PUSH EVERYTHING TO THE RIGHT
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(player.fullName)
						  .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                        
                        Text(positionalRanking)
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.8))
                                    .stroke(teamColor.opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
                .zIndex(4)
                
                // 🔥 FIXED: Game matchup CENTERED
                VStack {
                    Spacer()
                    HStack {
                        Spacer() // 🔥 CENTER THE MATCHUP INFO
                        FantasyGameMatchupView(player: player)
                        Spacer()
                    }
                    .padding(.bottom, 50)
                }
                .zIndex(5)
                
                // 🔥 NEW: Stats section ONLY at bottom, doesn't interfere with anything else
                VStack {
                    Spacer()
                    HStack {
                        if let statLine = formatPlayerStatBreakdown() {
                            Text(statLine)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black.opacity(0.7))
                                        .stroke(teamColor.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
                .zIndex(6)
            }
            .frame(height: 140) // 🔥 EXPANDED: From 125 to 140 for stats space
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [Color.black, teamColor.opacity(0.1), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: 0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            colors: borderColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
                    .opacity(borderOpacity)
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius * 0.5,
                        x: 0,
                        y: 0
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .onTapGesture {
                showingPlayerDetail = true
            }
            .onAppear {
                setupGameData()
                if player.isLive {
                    startLiveAnimations()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                gameViewModel.refresh(week: currentWeek)
            }
            .onReceive(nflWeekService.$currentWeek) { newWeek in
                if currentWeek != newWeek {
                    currentWeek = newWeek
                    setupGameData()
                }
            }
        }
        .sheet(isPresented: $showingPlayerDetail) {
            NavigationView {
                if let sleeperPlayer = getSleeperPlayerData() {
                    PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: player.team ?? "")
                    )
                } else {
                    PlayerDetailFallbackView(player: player)
                }
            }
        }
        .task {
            // 🔥 IMPROVED: More aggressive stats loading with debug
            print("🏈 FantasyPlayerCard task started - Player: \(player.fullName)")
            
            if !hasAttemptedStatsLoad {
                hasAttemptedStatsLoad = true
                debugStatsStatus = "Loading..."
                
                if !livePlayersViewModel.statsLoaded {
                    print("🏈 Loading stats via shared instance...")
                    await livePlayersViewModel.loadAllPlayers()
                    print("🏈 Stats load completed. Stats count: \(livePlayersViewModel.playerStats.keys.count)")
                } else {
                    print("🏈 Stats already loaded. Count: \(livePlayersViewModel.playerStats.keys.count)")
                }
                
                debugStatsStatus = "Loaded"
            }
            
            if let team = player.team {
                if let nflTeam = NFLTeam.team(for: team) {
                    teamColor = nflTeam.primaryColor
                } else {
                    teamColor = NFLTeamColors.color(for: team)
                }
            }
        }
    }
    
    private func formatPlayerStatBreakdown() -> String? {
        guard let sleeperPlayer = getSleeperPlayerData() else {
            return nil
        }
        
        guard let stats = livePlayersViewModel.playerStats[sleeperPlayer.playerID] else {
            return nil
        }
        
        let position = player.position
        var breakdown: [String] = []
        
        switch position {
        case "QB":
            if let attempts = stats["pass_att"], attempts > 0 {
                let completions = stats["pass_cmp"] ?? 0
                let yards = stats["pass_yd"] ?? 0
                let tds = stats["pass_td"] ?? 0
                breakdown.append("\(Int(completions))/\(Int(attempts)) CMP")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) PASS TD") }
                
                if let passFd = stats["pass_fd"], passFd > 0 {
                    breakdown.append("\(Int(passFd)) PASS FD")
                }
            }
            
            if let carries = stats["rush_att"], carries > 0 {
                let rushYards = stats["rush_yd"] ?? 0
                let rushTds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if rushYards > 0 { breakdown.append("\(Int(rushYards)) RUSH YD") }
                if rushTds > 0 { breakdown.append("\(Int(rushTds)) RUSH TD") }
                
                if let rushFd = stats["rush_fd"], rushFd > 0 {
                    breakdown.append("\(Int(rushFd)) RUSH FD")
                }
            }
            
        case "RB":
            if let carries = stats["rush_att"], carries > 0 {
                let yards = stats["rush_yd"] ?? 0
                let tds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
            }
            if let receptions = stats["rec"], receptions > 0 {
                let recYards = stats["rec_yd"] ?? 0
                let recTds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions)) REC")
                if recYards > 0 { breakdown.append("\(Int(recYards)) REC YD") }
                if recTds > 0 { breakdown.append("\(Int(recTds)) REC TD") }
            }
            
        case "WR", "TE":
            if let receptions = stats["rec"], receptions > 0 {
                let targets = stats["rec_tgt"] ?? receptions
                let yards = stats["rec_yd"] ?? 0
                let tds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
            }
            if position == "WR", let rushYards = stats["rush_yd"], rushYards > 0 {
                breakdown.append("\(Int(rushYards)) RUSH YD")
            }
            
        case "K":
            if let fgMade = stats["fgm"], fgMade > 0 {
                let fgAtt = stats["fga"] ?? fgMade
                breakdown.append("\(Int(fgMade))/\(Int(fgAtt)) FG")
            }
            if let xpMade = stats["xpm"], xpMade > 0 {
                breakdown.append("\(Int(xpMade)) XP")
            }
            
        case "DEF", "DST":
            if let sacks = stats["def_sack"], sacks > 0 {
                breakdown.append("\(Int(sacks)) SACK")
            }
            if let ints = stats["def_int"], ints > 0 {
                breakdown.append("\(Int(ints)) INT")
            }
            if let fumRec = stats["def_fum_rec"], fumRec > 0 {
                breakdown.append("\(Int(fumRec)) FUM REC")
            }
            
        default:
            return nil
        }
        
        return breakdown.isEmpty ? nil : breakdown.joined(separator: ", ")
    }
    
    private func startLiveAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
    
    private func setupGameData() {
        guard let team = player.team else { return }
        
        currentWeek = nflWeekService.currentWeek
        let currentYear = nflWeekService.currentYear
        
        gameViewModel.configure(for: team, week: currentWeek, year: Int(currentYear) ?? 2024)
    }
    
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = player.fullName
        
        // Find all potential matches first
        let potentialMatches = playerDirectory.players.values.filter { sleeperPlayer in
            if sleeperPlayer.fullName.lowercased() == playerName.lowercased() {
                return true
            }
            
            if sleeperPlayer.shortName.lowercased() == player.shortName.lowercased() &&
               sleeperPlayer.team?.lowercased() == player.team?.lowercased() {
                return true
            }
            
            if let firstName = sleeperPlayer.firstName, let lastName = sleeperPlayer.lastName {
                let fullName = "\(firstName) \(lastName)"
                if fullName.lowercased() == playerName.lowercased() {
                    return true
                }
            }
            
            return false
        }
        
        // If only one match, use it
        if potentialMatches.count == 1 {
            return potentialMatches.first
        }
        
        // 🔥 RESTORED: Robust prioritization system for multiple matches
        if potentialMatches.count > 1 {            
            // Priority 1: Player with detailed game stats (passing, rushing, receiving, etc.)
            let detailedStatsMatches = potentialMatches.filter { player in
                if let stats = livePlayersViewModel.playerStats[player.playerID] {
                    let hasDetailedStats = stats.keys.contains { key in
                        key.contains("pass_att") || key.contains("rush_att") || 
                        key.contains("rec") || key.contains("fgm") || 
                        key.contains("def_sack") || key.contains("pass_cmp") ||
                        key.contains("rush_yd") || key.contains("rec_yd")
                    }
                    return hasDetailedStats
                }
                return false
            }
            
            if !detailedStatsMatches.isEmpty {
                return detailedStatsMatches.first
            }
            
            // Priority 2: Player with any stats (even if just fantasy points)
            let anyStatsMatches = potentialMatches.filter { player in
                return livePlayersViewModel.playerStats[player.playerID] != nil
            }
            
            if !anyStatsMatches.isEmpty {
                return anyStatsMatches.first
            }
            
            // Priority 3: Player with most recent/current team match
            let teamMatches = potentialMatches.filter { player in
                return player.team?.lowercased() == self.player.team?.lowercased()
            }
            
            if !teamMatches.isEmpty {
                return teamMatches.first
            }
            
            // Priority 4: Fallback to first match
            return potentialMatches.first
        }
        
        return nil
    }
}

// MARK: -> Fantasy Game Matchup View (Real NFL Data)
struct FantasyGameMatchupView: View {
    let player: FantasyPlayer
    @StateObject private var gameViewModel = NFLGameMatchupViewModel()
    @State private var currentWeek: Int = NFLWeekService.shared.currentWeek
    @StateObject private var nflWeekService = NFLWeekService.shared
    
    var body: some View {
        VStack(spacing: 1) {
            if gameViewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                )
            } else if let gameInfo = gameViewModel.gameInfo {
                VStack(spacing: 1) {
                    Text(gameInfo.matchupString)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.8))
                        )
                        .id(gameInfo.matchupString)
                    
                    Text(gameInfo.formattedGameTime)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [NFLTeam.team(for: player.team ?? "")?.primaryColor ?? gameInfo.statusColor, .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .id(gameInfo.formattedGameTime)
                    
                    if gameInfo.isLive || gameInfo.gameStatus.lowercased().contains("final") || gameInfo.gameStatus.lowercased().contains("post") {
                        Text(gameInfo.scoreString)
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.gpGreen)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.black.opacity(0.6))
                            )
                            .id(gameInfo.scoreString)
                    }
                }
                .padding(.trailing, 8)
            } else {
                if let team = player.team {
                    let teamColor = NFLTeam.team(for: team)?.primaryColor ?? .purple
                    
                    VStack(spacing: 1) {
                        Text("\(team)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [teamColor.opacity(0.8), .clear]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                        
                        Text("BYE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [teamColor, .clear]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                    }
                    .padding(.trailing, 8)
                }
            }
        }
        .onAppear {
            setupGameData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            gameViewModel.refresh(week: currentWeek)
        }
        .onReceive(nflWeekService.$currentWeek) { newWeek in
            if currentWeek != newWeek {
                currentWeek = newWeek
                setupGameData()
            }
        }
    }
    
    private func setupGameData() {
        guard let team = player.team else { return }
        
        currentWeek = nflWeekService.currentWeek
        let currentYear = nflWeekService.currentYear
        
        gameViewModel.configure(for: team, week: currentWeek, year: Int(currentYear) ?? 2024)
    }
}

struct PlayerDetailFallbackView: View {
    let player: FantasyPlayer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            AsyncImage(url: player.headshotURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.gray)
                    .overlay(
                        Text(player.shortName.prefix(2))
                            .font(.title)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            
            VStack(spacing: 8) {
                Text(player.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    Text(player.position)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(positionColor(player.position))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if let team = player.team {
                        Text(team)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let jersey = player.jerseyNumber {
                        Text("#\(jersey)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Current Points")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(player.currentPointsString)
                        .fontWeight(.bold)
                        .foregroundColor(.gpGreen)
                }
                
                if let projected = player.projectedPoints {
                    HStack {
                        Text("Projected Points")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", projected))
                            .fontWeight(.bold)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            Text("Detailed stats unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle(player.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func positionColor(_ position: String) -> Color {
        switch position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
}