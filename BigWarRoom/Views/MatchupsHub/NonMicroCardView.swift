//
//  NonMicroCardView.swift
//  BigWarRoom
//
//  Independent non-micro matchup card view - contains all original MatchupCardView logic
//

import SwiftUI

struct NonMicroCardView: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    let onTap: () -> Void
    
    @State private var cardScale: CGFloat = 1.0 // FIXED: Remove slow scale animation
    @State private var scoreAnimation: Bool = false
    @State private var glowIntensity: Double = 0.0
    
    // NEW: Customizable card gradient color
    private let cardGrad: Color = .rockiesPrimary
    
    var body: some View {
        Button(action: {
            handleTap()
        }) {
            // 🔥 CONDITIONAL CONTENT: Show eliminated state or regular card
            if isMyManagerEliminated {
                eliminatedCardContent
            } else {
                cardContent
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(cardScale)
        .onAppear {
            // Cards should appear instantly with team colors
            
            // FIXED: Use centralized live detection instead of roster-based custom logic
            if matchup.isLive {
                startLiveAnimations()
            }
            
            // 🔥 NEW: Start eliminated animation if eliminated
            if isMyManagerEliminated {
                startEliminatedAnimation()
            }
        }
    }
    
    // MARK: -> Eliminated Card Content
    
    private var eliminatedCardContent: some View {
        VStack(spacing: 6) {
            // Header with league info (full league name)
            HStack {
                // League name with platform logo - FULL WIDTH
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
                    
                    Text("\(matchup.league.league.name)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer()
            }
            
            // CHOPPED badge - second row
            HStack {
                if matchup.isChoppedLeague {
                    Text("🔥 CHOPPED")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.2))
                        )
                }
                
                Spacer()
            }
            
            // Main eliminated content - COMPACT
            VStack(spacing: 4) {
                // ELIMINATED text without skulls (fits one line)
                Text("ELIMINATED")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .tracking(1.5)
                
                // Skulls on separate line
                HStack(spacing: 8) {
                    Text("💀")
                        .font(.system(size: 24))
                        .scaleEffect(eliminatedPulse ? 1.1 : 1.0)
                    
                    Text("☠️")
                        .font(.system(size: 24))
                        .scaleEffect(eliminatedPulse ? 1.1 : 1.0)
                }
                
                // Week and manager info - COMPACT
                VStack(spacing: 2) {
                    if let week = myEliminationWeek {
                        Text("Week \(week)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Manager name (if available)
                    if let myTeam = matchup.myTeam {
                        Text(myTeam.ownerName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Footer - just time (NO SPACER!)
            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    
                    Text(timeAgo(matchup.lastUpdated))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Tap hint
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(eliminatedCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.red, .black, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.0
                )
        )
        .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 2)
        .frame(height: 142)
    }
    
    // MARK: -> Eliminated Card Background
    
    private var eliminatedCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                // 🔥 ELIMINATED GRADIENT: Use gpRedPink
                LinearGradient(
                    colors: [
                        Color.gpRedPink.opacity(0.8),
                        Color.black.opacity(0.9),
                        Color.gpRedPink.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4)) // Darken for readability
            )
    }
    
    @State private var eliminatedPulse: Bool = false
    
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
        .padding(.vertical, 14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: overlayBorderColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: overlayBorderWidth
                )
                .opacity(overlayBorderOpacity)
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: 2
        )
        .frame(height: 142)
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
            .background(
                // TeamAssetManager-style gradient background using cardGrad - REMOVED opacity
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [cardGrad.opacity(0.8), cardGrad],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(cardGrad.opacity(0.3), lineWidth: 1)
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
                
                Text("\(matchup.league.league.name)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            
            Spacer()
            
            // LIVE status badge based on roster analysis
            if !matchup.isChoppedLeague {
                liveStatusBadge
            }
        }
    }
    
    private var compactMatchupContent: some View {
        VStack(spacing: 12) {
            // 🔥 FIXED: Teams row - HOME on LEFT, AWAY on RIGHT (respecting actual home/away designations)
            HStack(spacing: 8) {
                // 🔥 FIXED: Home team on LEFT (regardless of if it's me or opponent)
                if let homeTeam = getHomeTeam() {
                    compactTeamSection(homeTeam, isMyTeam: homeTeam.id == matchup.myTeam?.id)
                }
                
                // VS separator
                Text("VS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24)
                
                // 🔥 FIXED: Away team on RIGHT (regardless of if it's me or opponent)
                if let awayTeam = getAwayTeam() {
                    compactTeamSection(awayTeam, isMyTeam: awayTeam.id == matchup.myTeam?.id)
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
                            .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                        
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
        // Determine if this team is winning the matchup using passed isWinning parameter
        let isTeamWinning: Bool = {
            if isMyTeam {
                return isWinning // Use the passed isWinning for my team
            } else {
                return !isWinning // Opponent is winning if I'm not winning
            }
        }()
        
        return VStack(spacing: 6) {
            // Avatar - FIXED: Don't let AsyncImage block the team color display
            Group {
                if let avatarURL = team.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Show team initials immediately while avatar loads
                        compactTeamInitials(team, isWinning: isTeamWinning)
                    }
                    .frame(width: 45, height: 45)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                isTeamWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                                lineWidth: isTeamWinning ? 2 : 1
                            )
                    )
                } else {
                    compactTeamInitials(team, isWinning: isTeamWinning)
                        .frame(width: 45, height: 45)
                        .overlay(
                            Circle()
                                .stroke(
                                    isTeamWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                                    lineWidth: isTeamWinning ? 2 : 1
                                )
                        )
                }
            }
            
            // Team name - COMPACT - Pink for losers
            Text(team.ownerName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
                .lineLimit(1)
                .frame(maxWidth: 60)
            
            // Score - PROMINENT - Pink for losers
            Text(team.currentScoreString)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
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
    
    // 🔥 USE COMPUTED PROPERTY: Check if MY manager is eliminated
    private var isMyManagerEliminated: Bool {
        return matchup.isMyManagerEliminated
    }
    
    private var myEliminationWeek: Int? {
        return matchup.myEliminationWeek
    }
    
    // 🔥 ELIMINATED overlay for non-micro cards
    private var nonMicroEliminatedOverlay: some View {
        VStack {
            HStack {
                Spacer()
                
                // 🔥 ELIMINATED BADGE - Top right corner
                HStack(spacing: 4) {
                    Text("💀")
                        .font(.system(size: 14))
                    
                    Text("ELIMINATED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Text("☠️")
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .red.opacity(0.6), radius: 4)
            }
            .padding(.top, 8)
            .padding(.trailing, 12)
            
            Spacer()
            
            // Week eliminated at bottom if available
            if let week = myEliminationWeek {
                HStack {
                    Spacer()
                    Text("Eliminated Week \(week)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.bottom, 8)
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Allow taps to pass through
    }
    
    private var isLiveGame: Bool {
        // Use the centralized UnifiedMatchup.isLive property
        return matchup.isLive
    }
    
    private var overlayBorderColors: [Color] {
        if matchup.isChoppedLeague {
            if let ranking = matchup.myTeamRanking {
                let dangerColor = ranking.eliminationStatus.color
                return [dangerColor, dangerColor.opacity(0.7), dangerColor]
            }
            return [.orange, .orange.opacity(0.7), .orange]
        } else if isLiveGame {
            return [.gpGreen, .gpGreen.opacity(0.8), .cyan.opacity(0.6), .gpGreen.opacity(0.9), .gpGreen]
        } else {
            return [.blue.opacity(0.6), .cyan.opacity(0.4), .blue.opacity(0.6)]
        }
    }
    
    private var overlayBorderWidth: CGFloat {
        if matchup.isChoppedLeague {
            return 2.5
        } else if isLiveGame {
            return 2
        } else {
            return 1.5  // FIXED: Slightly thicker border for regular matchups
        }
    }
    
    private var overlayBorderOpacity: Double {
        if matchup.isChoppedLeague {
            return 0.9
        } else if isLiveGame {
            // FIXED: Ensure live borders are always visible with minimum opacity
            return max(0.6, glowIntensity * 0.8 + 0.2)
        } else {
            return 0.7
        }
    }
    
    private var shadowColor: Color {
        if matchup.isChoppedLeague {
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
    
    private var shadowRadius: CGFloat {
        if matchup.isChoppedLeague {
            return 8
        } else if isLiveGame {
            return 6
        } else {
            return 3
        }
    }
    
    private var backgroundColors: [Color] {
        if matchup.isChoppedLeague {
            if let ranking = matchup.myTeamRanking {
                let dangerColor = ranking.eliminationStatus.color
                return [
                    Color.black.opacity(0.9),
                    dangerColor.opacity(0.03),
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
    
    // 🔥 NEW: Eliminated animation
    private func startEliminatedAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            eliminatedPulse = true
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: -> Live Status Badge
    
    private var liveStatusBadge: some View {
        Text("LIVE")
            .font(.system(size: matchup.isLive ? 10 : 8, weight: .black))
            .foregroundColor(matchup.isLive ? .gpGreen : .gpRedPink.opacity(0.4))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((matchup.isLive ? Color.gpGreen : Color.gpRedPink).opacity(matchup.isLive ? 0.2 : 0.1))
            )
            .scaleEffect(matchup.isLive ? 1.0 : 0.9)
            .opacity(matchup.isLive ? 1.0 : 0.6)
    }
    
    // 🔥 FIXED: Helper functions to get home/away teams from actual FantasyMatchup data
    private func getHomeTeam() -> FantasyTeam? {
        return matchup.fantasyMatchup?.homeTeam
    }
    
    private func getAwayTeam() -> FantasyTeam? {
        return matchup.fantasyMatchup?.awayTeam
    }
}