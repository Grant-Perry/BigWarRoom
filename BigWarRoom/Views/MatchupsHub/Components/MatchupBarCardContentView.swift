//
//  MatchupBarCardContentView.swift
//  BigWarRoom
//
//  Main content for horizontal bar-style matchup cards
//

import SwiftUI

struct MatchupBarCardContentView: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    let isLineupOptimized: Bool
    let myProjected: Double
    let opponentProjected: Double
    let projectionsLoaded: Bool
    
    var body: some View {
        ZStack {
            // Background
            MatchupBarCardBackgroundView(
                matchup: matchup,
                isWinning: isWinning
            )
            
            // Main content
            VStack(spacing: 2) {
                // Top row: Manager names
                HStack(spacing: 12) {
                    // My manager name (left)
                    if let myTeam = matchup.myTeam {
                        Text(myTeam.ownerName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Opponent manager name (right)
                    if let opponent = matchup.opponentTeam {
                        Text(opponent.ownerName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // Second row: Avatars, Records, To Play, Scores, Delta
                HStack(spacing: 0) {
                    // My team section (left) - flexible width
                    HStack(spacing: 8) {
                        // My avatar (smaller)
                        if let myTeam = matchup.myTeam {
                            ZStack {
                                // Gradient background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                
                                // Avatar image or initials
                                if let avatarURL = myTeam.avatarURL {
                                    AsyncTeamAvatarView(
                                        url: avatarURL,
                                        size: 36,
                                        fallbackInitials: getInitials(from: myTeam.ownerName)
                                    )
                                    .onAppear {
                                        DebugPrint(mode: .espnAPI, "🖼️ MISSION CONTROL: Rendering MyTeam Avatar for \(myTeam.ownerName): \(avatarURL.absoluteString)")
                                    }
                                } else {
                                    Text(getInitials(from: myTeam.ownerName))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .onAppear {
                                            DebugPrint(mode: .espnAPI, "❌ MISSION CONTROL: NO avatarURL for \(myTeam.ownerName)")
                                            DebugPrint(mode: .espnAPI, "   - avatar field: \(myTeam.avatar ?? "nil")")
                                            DebugPrint(mode: .espnAPI, "   - team ID: \(myTeam.id)")
                                        }
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                        }
                        
                        // Record and To Play
                        VStack(alignment: .leading, spacing: 2) {
                            if let myTeam = matchup.myTeam {
                                Text(recordText(for: myTeam))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                Text("To play: \(toPlayCount(for: myTeam))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    
                    // Center: Scores with VS, Projected, and Delta
                    VStack(spacing: 6) {
                        // Current scores
                        HStack(spacing: 6) {
                            // My score
                            Text(FormattingService.formatPoints(matchup.myTeam?.currentScore ?? 0.0))
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                                .minimumScaleFactor(0.8)
                            
                            Text("vs")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            // Opponent score
                            Text(FormattingService.formatPoints(matchup.opponentTeam?.currentScore ?? 0.0))
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(isWinning ? .gpRedPink : .gpGreen)
                                .minimumScaleFactor(0.8)
                        }
                        
                        // Projected scores as thermometer bar with win %
                        if projectionsLoaded && myProjected > 0 && opponentProjected > 0 {
                            VStack(spacing: 2) {
                                // Thermometer bar with win % overlay
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background bar
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 8)
                                        
                                        // 🔥 FIX: Use actual win probability, not projected score ratio
                                        // Filled portion (my team's win probability)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        winProbabilityValue >= 0.5 ? Color.gpGreen : Color.gpRedPink,
                                                        winProbabilityValue >= 0.5 ? Color.gpGreen.opacity(0.7) : Color.gpRedPink.opacity(0.7)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * winProbabilityValue, height: 8)
                                        
                                        // Win percentage in center
                                        HStack {
                                            Spacer()
                                            Text(actualWinPercentageText)
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundColor(winProbabilityValue >= 0.5 ? .gpGreen : .gpRedPink)
                                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 0)
                                            Spacer()
                                        }
                                    }
                                }
                                .frame(height: 8)
                                
                                // Projected scores on either end
                                HStack(spacing: 0) {
                                    Text(FormattingService.formatPoints(myProjected))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(winProbabilityValue >= 0.5 ? .gpGreen : .gpRedPink)
                                    
                                    Spacer()
                                    
                                    Text(FormattingService.formatPoints(opponentProjected))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(winProbabilityValue >= 0.5 ? .gpRedPink : .gpGreen)
                                }
                            }
                            .frame(width: 120)
                            .onAppear {
                                DebugPrint(mode: .liveUpdates, "🎯 DISPLAY: My(\(matchup.myTeam?.ownerName ?? "?"))=\(myProjected) vs Opp(\(matchup.opponentTeam?.ownerName ?? "?"))=\(opponentProjected)")
                            }
                        }
                    }
                    .frame(width: 140)
                    
                    // Opponent section (right) - flexible width
                    HStack(spacing: 8) {
                        // Record and To Play
                        VStack(alignment: .trailing, spacing: 2) {
                            if let opponent = matchup.opponentTeam {
                                Text(recordText(for: opponent))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                Text("To play: \(toPlayCount(for: opponent))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                        
                        // Opponent avatar (smaller)
                        if let opponent = matchup.opponentTeam {
                            ZStack {
                                // Gradient background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.6), Color.red.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                
                                // Avatar image or initials
                                if let avatarURL = opponent.avatarURL {
                                    AsyncTeamAvatarView(
                                        url: avatarURL,
                                        size: 36,
                                        fallbackInitials: getInitials(from: opponent.ownerName)
                                    )
                                    .onAppear {
                                        DebugPrint(mode: .espnAPI, "🖼️ MISSION CONTROL: Rendering Opponent Avatar for \(opponent.ownerName): \(avatarURL.absoluteString)")
                                    }
                                } else {
                                    Text(getInitials(from: opponent.ownerName))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .onAppear {
                                            DebugPrint(mode: .espnAPI, "❌ MISSION CONTROL: NO avatarURL for \(opponent.ownerName)")
                                            DebugPrint(mode: .espnAPI, "   - avatar field: \(opponent.avatar ?? "nil")")
                                            DebugPrint(mode: .espnAPI, "   - team ID: \(opponent.id)")
                                        }
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                }
                .padding(.vertical, 4)
                
                // Bottom row: League name, Delta, RX, Status
                HStack(spacing: 12) {
                    // League name with logo (SMALLER)
                    HStack(spacing: 6) {
                        // League logo - much smaller
                        Group {
                            switch matchup.league.source {
                            case .sleeper:
                                AppConstants.sleeperLogo
                            case .espn:
                                AppConstants.espnLogo
                            }
                        }
                        .scaleEffect(0.35)
                        .frame(width: 14, height: 14)
                        
                        Text(matchup.league.league.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                    )
                    
                    Spacer()
                    
                    // Status indicators (right)
                    HStack(spacing: 8) {
                        // Live indicator
                        if matchup.isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.15))
                            )
                        }
                        
                        // Delta badge (medium size)
                        if let differential = matchup.scoreDifferential {
                            Text(FormattingService.formatPoints(abs(differential)))
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(differential >= 0 ? .gpGreen : .gpRedPink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill((differential >= 0 ? Color.gpGreen : Color.gpRedPink).opacity(0.2))
                                        .overlay(
                                            Capsule()
                                                .stroke((differential >= 0 ? Color.gpGreen : Color.gpRedPink).opacity(0.6), lineWidth: 1.5)
                                        )
                                )
                        }
                        
                        // RX button - LineupRX asset icon with green/red circle
                        NavigationLink(destination: LineupRXView(matchup: matchup)) {
                            ZStack {
                                // Glassmorphic background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                (isLineupOptimized ? Color.gpGreen : Color.gpRedPink).opacity(0.3),
                                                (isLineupOptimized ? Color.gpGreen : Color.gpRedPink).opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                (isLineupOptimized ? Color.gpGreen : Color.gpRedPink).opacity(0.6),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .frame(width: 24, height: 24)
                                    .shadow(color: (isLineupOptimized ? Color.gpGreen : Color.gpRedPink).opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                Image("LineupRX")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: UIScreen.main.bounds.width - 60)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    (isWinning ? Color.gpGreen : Color.gpRedPink).opacity(0.7),
                    lineWidth: 2
                )
        )
        .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helper Methods
    
    // 🔥 FIX: Use actual win probability instead of projected score ratio
    /// Get actual win probability value (0.0 to 1.0)
    private var winProbabilityValue: CGFloat {
        // Use matchup's win probability (which has deterministic logic)
        if let winProb = matchup.myWinProbability {
            return CGFloat(winProb)
        }
        // Fallback to 50-50 if unavailable
        return 0.5
    }
    
    /// Get win percentage text from actual win probability
    private var actualWinPercentageText: String {
        let percentage = Int(winProbabilityValue * 100)
        return "\(percentage)%"
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }
    
    private func recordText(for team: FantasyTeam) -> String {
        guard let record = team.record else { return "0-0" }
        return FormattingService.formatRecord(record)
    }
    
    private func toPlayCount(for team: FantasyTeam) -> Int {
        return team.playersYetToPlay(gameStatusService: GameStatusService.shared)
    }
    
    private var shadowColor: Color {
        if matchup.isLive {
            return isWinning ? Color.gpGreen.opacity(0.3) : Color.gpRedPink.opacity(0.3)
        }
        return Color.black.opacity(0.2)
    }
}