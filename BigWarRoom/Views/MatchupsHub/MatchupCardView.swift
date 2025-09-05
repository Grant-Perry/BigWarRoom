//
//  MatchupCardView.swift
//  BigWarRoom
//
//  Beautiful animated matchup cards for the hub
//

import SwiftUI

struct MatchupCardView: View {
    let matchup: UnifiedMatchup
    let onTap: () -> Void
    
    @State private var cardScale: CGFloat = 0.95
    @State private var scoreAnimation: Bool = false
    @State private var glowIntensity: Double = 0.0
    
    var body: some View {
        Button(action: {
            handleTap()
        }) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(cardScale)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                cardScale = 1.0
            }
            
            if matchup.fantasyMatchup?.status == .live {
                startLiveAnimations()
            }
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Header with league info and live status
            cardHeader
            
            // Main matchup content
            if matchup.isChoppedLeague {
                choppedLeagueContent
            } else {
                standardMatchupContent
            }
            
            // Footer with additional info
            cardFooter
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: borderColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isLiveGame ? 2 : 1
                )
                .opacity(isLiveGame ? (glowIntensity * 0.8 + 0.2) : 0.3)
        )
        .shadow(
            color: isLiveGame ? .gpGreen.opacity(glowIntensity * 0.5) : .black.opacity(0.3),
            radius: isLiveGame ? 8 : 4,
            x: 0,
            y: isLiveGame ? 4 : 2
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var cardHeader: some View {
        HStack {
            // League platform badge
            leaguePlatformBadge
            
            Spacer()
            
            // Live status indicator
            if isLiveGame {
                liveStatusBadge
            } else if let status = matchup.fantasyMatchup?.status {
                gameStatusBadge(status)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var leaguePlatformBadge: some View {
        HStack(spacing: 6) {
            // Platform icon
            Image(systemName: platformIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            
            // League name
            Text(matchup.league.league.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(platformColor.opacity(0.8))
        )
    }
    
    private var liveStatusBadge: some View {
        HStack(spacing: 6) {
            // Platform logo
            platformLogo
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(glowIntensity * 0.5 + 0.5)
                
                Text("LIVE")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private func gameStatusBadge(_ status: MatchupStatus) -> some View {
        HStack(spacing: 6) {
            // Platform logo
            platformLogo
            
            HStack(spacing: 4) {
                Text(status.emoji)
                    .font(.system(size: 10))
                
                Text(status.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(statusColor(status))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusColor(status).opacity(0.2))
        )
    }
    
    private var platformLogo: some View {
        Group {
            switch matchup.league.source {
            case .espn:
                AppConstants.espnLogo
                    .frame(width: 16, height: 16)
                    .scaleEffect(0.5)  // Scale down the logo
            case .sleeper:
                AppConstants.sleeperLogo
                    .frame(width: 16, height: 16)
                    .scaleEffect(0.5)  // Scale down the logo
            }
        }
    }
    
    private var standardMatchupContent: some View {
        VStack(spacing: 20) {
            // Teams and scores
            HStack(spacing: 0) {
                // My team (left side)
                if let myTeam = matchup.myTeam {
                    teamSection(myTeam, isMyTeam: true)
                }
                
                // VS separator with win probability
                vsSeparator
                
                // Opponent team (right side)
                if let opponentTeam = matchup.opponentTeam {
                    teamSection(opponentTeam, isMyTeam: false)
                }
            }
            
            // Win probability bar
            if let winProb = matchup.myWinProbability {
                winProbabilityBar(winProb)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var choppedLeagueContent: some View {
        VStack(spacing: 16) {
            // Chopped league header
            HStack {
                Text("🔥 CHOPPED LEAGUE")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.orange)
                
                Spacer()
                
                if let summary = matchup.choppedSummary {
                    Text("Week \(summary.week)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // MY chopped status - use the same design as ChoppedLeaderboardView
            if let ranking = matchup.myTeamRanking {
                ChoppedPlayerCard(ranking: ranking)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func teamSection(_ team: FantasyTeam, isMyTeam: Bool) -> some View {
        VStack(spacing: 8) {
            // Team avatar/logo
            teamAvatar(team, isMyTeam: isMyTeam)
            
            // Team name
            Text(team.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 36)
            
            // Owner name
            Text(team.ownerName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
            
            // Score
            VStack(spacing: 2) {
                Text(team.currentScoreString)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(isMyTeam ? .gpGreen : .white)
                    .scaleEffect(scoreAnimation && isLiveGame ? 1.1 : 1.0)
                
                Text("(\(team.projectedScoreString))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            // Record
            if let record = team.record {
                Text(record.displayString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func teamAvatar(_ team: FantasyTeam, isMyTeam: Bool) -> some View {
        Group {
            if let avatarURL = team.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    teamInitialsBadge(team, isMyTeam: isMyTeam)
                }
            } else {
                teamInitialsBadge(team, isMyTeam: isMyTeam)
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    isMyTeam ? Color.gpGreen : Color.white.opacity(0.3),
                    lineWidth: isMyTeam ? 3 : 2
                )
        )
    }
    
    private func teamInitialsBadge(_ team: FantasyTeam, isMyTeam: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isMyTeam ? [.gpGreen.opacity(0.8), .gpGreen] : [team.espnTeamColor.opacity(0.8), team.espnTeamColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(team.teamInitials)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.white)
        }
    }
    
    private var vsSeparator: some View {
        VStack(spacing: 4) {
            Text("VS")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.white.opacity(0.7))
            
            // Score differential
            if let differential = matchup.scoreDifferential {
                Text(differential > 0 ? "+\(String(format: "%.1f", differential))" : String(format: "%.1f", differential))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(differential > 0 ? .green : .red)
            }
        }
        .frame(width: 40)
    }
    
    private func winProbabilityBar(_ winProb: Double) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Win Probability")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(winProb * 100))% - \(Int((1 - winProb) * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    // Win probability fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.gpGreen, .gpGreen.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * winProb, height: 8)
                        .animation(.easeInOut(duration: 1.0), value: winProb)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func choppedStatusSection(_ ranking: FantasyTeamRanking) -> some View {
        HStack(spacing: 16) {
            // Rank and status
            VStack(spacing: 4) {
                Text(ranking.rankDisplay)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(ranking.eliminationStatus.color)
                
                Text(ranking.eliminationStatus.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ranking.eliminationStatus.color)
            }
            
            // Score and safety margin
            VStack(spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Points This Week")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Safety margin
            VStack(spacing: 4) {
                Text(ranking.safetyMarginDisplay)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ranking.pointsFromSafety >= 0 ? .green : .red)
                
                Text("From Safety")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ranking.eliminationStatus.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ranking.eliminationStatus.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func choppedLeaderboardPreview(_ summary: ChoppedWeekSummary) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Leaderboard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(summary.totalSurvivors) Survivors")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            LazyVStack(spacing: 4) {
                ForEach(Array(summary.rankings.prefix(3).enumerated()), id: \.offset) { index, ranking in
                    HStack {
                        Text("\(index + 1).")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, alignment: .leading)
                        
                        Text(ranking.team.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(ranking.weeklyPointsString)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ranking.eliminationStatus.color)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var cardFooter: some View {
        HStack {
            // Last updated
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                Text(timeAgo(matchup.lastUpdated))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Tap hint
            HStack(spacing: 4) {
                Text("Tap for details")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: -> Computed Properties
    
    private var isLiveGame: Bool {
        matchup.fantasyMatchup?.status == .live
    }
    
    private var platformIcon: String {
        switch matchup.league.source {
        case .espn: return "tv"
        case .sleeper: return "moon.zzz"
        }
    }
    
    private var platformColor: Color {
        switch matchup.league.source {
        case .espn: return .red
        case .sleeper: return .blue
        }
    }
    
    private var backgroundColors: [Color] {
        if isLiveGame {
            return [
                Color.black.opacity(0.9),
                Color.gpGreen.opacity(0.1),
                Color.black.opacity(0.9)
            ]
        } else {
            return [
                Color.black.opacity(0.8),
                Color.gray.opacity(0.1),
                Color.black.opacity(0.8)
            ]
        }
    }
    
    private var borderColors: [Color] {
        if isLiveGame {
            return [.gpGreen, .blue, .gpGreen]
        } else {
            return [.gray.opacity(0.3), .gray.opacity(0.1), .gray.opacity(0.3)]
        }
    }
    
    private func statusColor(_ status: MatchupStatus) -> Color {
        switch status {
        case .upcoming: return .blue
        case .live: return .red
        case .complete: return .green
        }
    }
    
    // MARK: -> Animation & Interaction
    
    private func handleTap() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Scale animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            cardScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                cardScale = 1.0
            }
            onTap()
        }
    }
    
    private func startLiveAnimations() {
        // Pulsing glow for live games
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
        
        // Score pulsing animation
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scoreAnimation.toggle()
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: -> Preview
#Preview {
    let sampleLeague = SleeperLeague(
        leagueID: "123456", 
        name: "Championship League", 
        status: .complete, 
        sport: "nfl", 
        season: "2024", 
        seasonType: "regular", 
        totalRosters: 12, 
        draftID: nil, 
        avatar: nil, 
        settings: nil, 
        scoringSettings: nil, 
        rosterPositions: nil
    )
    
    let sampleMatchup = UnifiedMatchup(
        id: "sample_1",
        league: UnifiedLeagueManager.LeagueWrapper(
            id: "sleeper_123",
            league: sampleLeague,
            source: .sleeper,
            client: SleeperAPIClient.shared
        ),
        fantasyMatchup: FantasyMatchup(
            id: "matchup_1",
            leagueID: "sleeper_123",
            week: NFLWeekService.shared.currentWeek,
            year: "2024",
            homeTeam: FantasyTeam(
                id: "team_1",
                name: "Gp's Gladiators",
                ownerName: "Gp",
                record: TeamRecord(wins: 10, losses: 4, ties: nil),
                avatar: nil,
                currentScore: 127.5,
                projectedScore: 142.8,
                roster: [],
                rosterID: 1
            ),
            awayTeam: FantasyTeam(
                id: "team_2",
                name: "Thunder Bolts",
                ownerName: "Opponent",
                record: TeamRecord(wins: 8, losses: 6, ties: nil),
                avatar: nil,
                currentScore: 98.2,
                projectedScore: 115.6,
                roster: [],
                rosterID: 2
            ),
            status: .live,
            winProbability: 0.75
        ),
        choppedSummary: nil,
        lastUpdated: Date()
    )
    
    MatchupCardView(matchup: sampleMatchup) {
        print("Card tapped!")
    }
    .padding()
    .background(Color.black)
}