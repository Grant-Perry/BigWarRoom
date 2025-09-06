//
//  MatchupCardView.swift
//  BigWarRoom
//
//  Beautiful animated matchup cards for the hub - COMPACT DESIGN
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
        VStack(spacing: 8) {
            // Compact header with league and status
            cardHeader
            
            // Main content
            if matchup.isChoppedLeague {
                compactChoppedContent
            } else {
                compactMatchupContent
            }
            
            // Compact footer
            compactFooter
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14) // INCREASED from 12 to 14 for more breathing room
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: overlayBorderColors, // UPDATED: Use dynamic colors based on chopped status
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: overlayBorderWidth // UPDATED: Use dynamic border width
                )
                .opacity(overlayBorderOpacity) // UPDATED: Use dynamic opacity
        )
        .shadow(
            color: shadowColor, // UPDATED: Use dynamic shadow color
            radius: shadowRadius, // UPDATED: Use dynamic shadow radius
            x: 0,
            y: 2
        )
        .frame(height: 142) // REDUCED from 145 to 142 to work better with increased row spacing
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
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
            // League name with platform logo
            HStack(spacing: 6) {
                Group {
                    switch matchup.league.source {
                    case .espn:
                        AppConstants.espnLogo
                            .scaleEffect(0.4)
                    case .sleeper:
                        AppConstants.sleeperLogo
                            .scaleEffect(0.4)
                    }
                }
                .frame(width: 16, height: 16)
                
                Text(matchup.league.league.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            
            Spacer()
        }
    }
    
    private var compactMatchupContent: some View {
        VStack(spacing: 12) {
            // Teams row - HORIZONTAL layout
            HStack(spacing: 8) {
                // My team
                if let myTeam = matchup.myTeam {
                    compactTeamSection(myTeam, isMyTeam: true)
                }
                
                // VS separator
                Text("VS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24)
                
                // Opponent team
                if let opponentTeam = matchup.opponentTeam {
                    compactTeamSection(opponentTeam, isMyTeam: false)
                }
            }
            
            // Win probability - COMPACT
            if let winProb = matchup.myWinProbability {
                compactWinProbability(winProb)
            }
        }
    }
    
    private var compactChoppedContent: some View {
        VStack(spacing: 8) {
            // Chopped status
            HStack {
                Text("🔥 CHOPPED")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.orange)
                
                Spacer()
                
                if let summary = matchup.choppedSummary {
                    Text("Week \(summary.week)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // My status
            if let ranking = matchup.myTeamRanking {
                HStack {
                    // Rank
                    VStack(spacing: 2) {
                        Text("#\(ranking.rank)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(ranking.eliminationStatus.color)
                        
                        Text(ranking.eliminationStatus.emoji)
                            .font(.system(size: 12))
                    }
                    
                    Spacer()
                    
                    // Score
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ranking.weeklyPointsString)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(ranking.safetyMarginDisplay)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ranking.pointsFromSafety >= 0 ? .green : .red)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ranking.eliminationStatus.color.opacity(0.1))
                )
            }
        }
    }
    
    private func compactTeamSection(_ team: FantasyTeam, isMyTeam: Bool) -> some View {
        // Determine if this team is winning the matchup
        let isWinning: Bool = {
            if let myTeam = matchup.myTeam, let opponentTeam = matchup.opponentTeam {
                let myScore = myTeam.currentScore ?? 0
                let opponentScore = opponentTeam.currentScore ?? 0
                
                if isMyTeam {
                    return myScore > opponentScore // I'm winning if my score > opponent score
                } else {
                    return opponentScore > myScore // Opponent is winning if their score > my score
                }
            }
            return false
        }()
        
        return VStack(spacing: 6) {
            // Avatar - BIGGER
            Group {
                if let avatarURL = team.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        compactTeamInitials(team, isWinning: isWinning)
                    }
                } else {
                    compactTeamInitials(team, isWinning: isWinning)
                }
            }
            .frame(width: 45, height: 45)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        isWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                        lineWidth: isWinning ? 2 : 1
                    )
            )
            
            // Team name - COMPACT - Pink for losers
            Text(team.ownerName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                .lineLimit(1)
                .frame(maxWidth: 60)
            
            // Score - PROMINENT - Pink for losers
            Text(team.currentScoreString)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                .scaleEffect(scoreAnimation && isLiveGame ? 1.1 : 1.0)
            
            // Record - TINY
            if let record = team.record {
                Text(record.displayString)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func compactTeamInitials(_ team: FantasyTeam, isWinning: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isWinning ? [.gpGreen.opacity(0.8), .gpGreen] : [team.espnTeamColor.opacity(0.8), team.espnTeamColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(team.teamInitials)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.white)
        }
    }
    
    private func compactWinProbability(_ winProb: Double) -> some View {
        VStack(spacing: 4) {
            // Probability text
            HStack {
                Text("\(Int(winProb * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Spacer()
                
                Text("\(Int((1 - winProb) * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Probability bar - THIN
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gpGreen)
                        .frame(width: geometry.size.width * winProb, height: 4)
                        .animation(.easeInOut(duration: 1.0), value: winProb)
                }
            }
            .frame(height: 4)
        }
    }
    
    private var compactFooter: some View {
        HStack {
            // Time ago - SMALLER
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                
                Text(timeAgo(matchup.lastUpdated))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Score differential - if available
            if let differential = matchup.scoreDifferential {
                Text(differential > 0 ? "+\(String(format: "%.1f", differential))" : String(format: "%.1f", differential))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(differential > 0 ? .green : .red)
            }
            
            Spacer()
            
            // Tap hint - MINIMAL
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray.opacity(0.6))
        }
    }
    
    // MARK: -> Computed Properties
    
    private var isLiveGame: Bool {
        matchup.fantasyMatchup?.status == .live
    }
    
    // UPDATED: Dynamic border colors based on chopped danger level or live game status
    private var overlayBorderColors: [Color] {
        if matchup.isChoppedLeague {
            // Use chopped danger level colors
            if let ranking = matchup.myTeamRanking {
                let dangerColor = ranking.eliminationStatus.color
                return [dangerColor, dangerColor.opacity(0.7), dangerColor]
            }
            return [.orange, .orange.opacity(0.7), .orange] // Fallback chopped color
        } else if isLiveGame {
            // Live game colors
            return [.gpGreen, .blue, .gpGreen]
        } else {
            // Regular game colors
            return [.gray.opacity(0.3), .gray.opacity(0.1), .gray.opacity(0.3)]
        }
    }
    
    // UPDATED: Dynamic border width
    private var overlayBorderWidth: CGFloat {
        if matchup.isChoppedLeague {
            // Thicker borders for chopped leagues to emphasize danger
            return 2.5
        } else if isLiveGame {
            return 2
        } else {
            return 1
        }
    }
    
    // UPDATED: Dynamic border opacity
    private var overlayBorderOpacity: Double {
        if matchup.isChoppedLeague {
            return 0.9 // High opacity for chopped borders
        } else if isLiveGame {
            return (glowIntensity * 0.8 + 0.2)
        } else {
            return 0.3
        }
    }
    
    // UPDATED: Dynamic shadow color
    private var shadowColor: Color {
        if matchup.isChoppedLeague {
            // Shadow matches the danger level
            if let ranking = matchup.myTeamRanking {
                return ranking.eliminationStatus.color.opacity(0.4)
            }
            return .orange.opacity(0.4)
        } else if isLiveGame {
            return .gpGreen.opacity(glowIntensity * 0.3)
        } else {
            return .black.opacity(0.2)
        }
    }
    
    // UPDATED: Dynamic shadow radius
    private var shadowRadius: CGFloat {
        if matchup.isChoppedLeague {
            // Bigger shadow for chopped leagues - more dramatic
            return 8
        } else if isLiveGame {
            return 6
        } else {
            return 3
        }
    }
    
    private var backgroundColors: [Color] {
        if matchup.isChoppedLeague {
            // Chopped leagues get subtle danger-level tinted backgrounds
            if let ranking = matchup.myTeamRanking {
                let dangerColor = ranking.eliminationStatus.color
                return [
                    Color.black.opacity(0.9),
                    dangerColor.opacity(0.03), // Very subtle tint
                    Color.black.opacity(0.9)
                ]
            }
            return [
                Color.black.opacity(0.9),
                Color.orange.opacity(0.03),
                Color.black.opacity(0.9)
            ]
        } else if isLiveGame {
            return [
                Color.black.opacity(0.9),
                Color.gpGreen.opacity(0.05),
                Color.black.opacity(0.9)
            ]
        } else {
            return [
                Color.black.opacity(0.8),
                Color.gray.opacity(0.05),
                Color.black.opacity(0.8)
            ]
        }
    }
    
    private var borderColors: [Color] {
        // This is now replaced by overlayBorderColors above, but keeping for compatibility
        if isLiveGame {
            return [.gpGreen, .blue, .gpGreen]
        } else {
            return [.gray.opacity(0.3), .gray.opacity(0.1), .gray.opacity(0.3)]
        }
    }

    // MARK: -> Animation & Interaction
    
    private func handleTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            cardScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                cardScale = 1.0
            }
            onTap()
        }
    }
    
    private func startLiveAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
        
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
    
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        ForEach(0..<4, id: \.self) { _ in
            MatchupCardView(matchup: sampleMatchup) {
                print("Card tapped!")
            }
        }
    }
    .padding()
    .background(Color.black)
}