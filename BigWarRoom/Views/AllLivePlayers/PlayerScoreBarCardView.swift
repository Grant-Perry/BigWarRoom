//
//  PlayerScoreBarCardView.swift
//  BigWarRoom
//
//  Seamless player card with animated score bar integration
//

import SwiftUI

struct PlayerScoreBarCardView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let animateIn: Bool
    let onTap: (() -> Void)?
    
    // 🔥 NEW: Get stats from parent view model
    @ObservedObject var viewModel: AllLivePlayersViewModel
    
    @State private var scoreBarWidth: Double = 0.0
    @State private var cardOffset: Double = 50.0
    @State private var cardOpacity: Double = 0.0
    @StateObject private var playerDirectory = PlayerDirectoryStore.shared
    
    private let maxScoreBarWidth: Double = 120.0 // Maximum width in points
    private let cardHeight: Double = 60.0 // Shorter card height (was 70)
    private let scoreBarHeight: Double = 20.0 // Shorter score bar (was 23.3)
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            // Just the player card - no separate scoreBar
            playerCardView
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            // LIVE border around the entire card
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    playerEntry.player.isLive ? 
                        LinearGradient(colors: [.blue, .gpGreen], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.gpYellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: playerEntry.player.isLive ? 3 : 2
                )
                .opacity(playerEntry.player.isLive ? 0.8 : 0.6)
        )
        .offset(y: animateIn ? cardOffset : 0)
        .opacity(animateIn ? cardOpacity : 1.0)
        .onAppear {
            if animateIn {
                // Animate card entrance first
                withAnimation(.easeOut(duration: 0.5)) {
                    cardOffset = 0.0
                    cardOpacity = 1.0
                }
                
                // Animate score bar from left to right after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        scoreBarWidth = playerEntry.scoreBarWidth
                    }
                }
            } else {
                // If not animating in, set final state immediately
                // Force a small delay to ensure view is fully laid out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scoreBarWidth = playerEntry.scoreBarWidth
                }
            }
        }
        .onChange(of: playerEntry.scoreBarWidth) { _, newWidth in
            // Smooth animation when scores update (left to right growth)
            withAnimation(.easeInOut(duration: 0.6)) {
                scoreBarWidth = newWidth
            }
        }
    }
    
    // MARK: - Player Card View
    
    private var playerCardView: some View {
        ZStack(alignment: .leading) {
            // Build the card content first (without image)
            HStack(spacing: 0) {
                // Empty space for where image will be overlaid
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 65) // Space for image
                
                // Player info
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        // Player name and position - with proper period formatting
                        Text(formattedPlayerName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Position badge
                        positionBadge
                        
                        // Team logo
                        teamLogoView
                        
                        Spacer()
                    }
                    
                    // Score and league info
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(playerEntry.currentScoreString)
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundColor(playerScoreColor)
                                
                                Text("pts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 🔥 NEW: Stat breakdown line - ONLY show if player has fantasy points > 0
                            if playerEntry.currentScore > 0, let statLine = formatPlayerStatBreakdown() {
                                Text(statLine)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        
                        Spacer()
                        
                        // League banner
                        leagueBanner
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(teamBackgroundView)
            
            // NOW overlay the player image on top - unconstrained!
            HStack {
                playerImageView
                    .offset(x: -10) // Move right instead of left (was x: -15)
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip the entire thing
    }
    
    // MARK: - Subviews
    
    private var playerImageView: some View {
        AsyncImage(url: playerEntry.player.headshotURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            playerFallbackView
        }
        .frame(width: 80, height: 100) // Bigger and taller - now unconstrained by card layout!
    }
    
    private var playerFallbackView: some View {
        Rectangle()
            .fill(teamGradient)
            .overlay(
                Text(playerEntry.player.firstName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private var positionBadge: some View {
        Text(playerEntry.position)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var teamLogoView: some View {
        Group {
            if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                TeamAssetManager.shared.logoOrFallback(for: team.id)
                    .frame(width: 20, height: 20) // Smaller logo (was 24x24)
            } else {
                Circle()
                    .fill(.gray)
                    .frame(width: 20, height: 20) // Smaller fallback
            }
        }
    }
    
    private var leagueBanner: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(leagueSourceColor)
                .frame(width: 6, height: 6)
            
            Text(playerEntry.leagueName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(2) // Allow 2 lines instead of 1
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(leagueSourceColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
    
    private var teamBackgroundView: some View {
        ZStack {
            // Base background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.2))
            
            // Score bar with sharp trailing edge for clear value representation
            HStack(spacing: 0) {
                ZStack {
                    // Main gradient background with abrupt trailing edge
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.clear, location: 0.0),                    // Start clear
                                    .init(color: originalScoreBarColor.opacity(0.3), location: 0.3), // Build up color
                                    .init(color: originalScoreBarColor.opacity(0.5), location: 0.7), // Peak color
                                    .init(color: originalScoreBarColor.opacity(0.6), location: 0.95), // Strong at edge
                                    .init(color: originalScoreBarColor.opacity(0.6), location: 1.0)   // Sharp cutoff
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Subtle overlay (toned down brightness)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.03),  // Much more subtle
                                    Color.clear,
                                    Color.white.opacity(0.01)   // Very subtle
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: calculateScoreBarWidth())
                .clipShape(RoundedRectangle(cornerRadius: 12)) // Ensure sharp edge
                
                Spacer()
            }
            
            // Team-specific background overlay
            Group {
                if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(team.backgroundColor.opacity(0.05))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6).opacity(0.05))
                }
            }
            
            HStack {
                Spacer()
                VStack {
                    performanceIndicator
                    Spacer()
                }
                .padding(.trailing, 8)
                .padding(.top, 6)
            }
        }
    }
    
    private func calculateScoreBarWidth() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 32 // Account for padding
        let minimumWidth = screenWidth * 0.15 // 15% minimum
        let calculatedWidth = screenWidth * scoreBarWidth
        
        // Ensure we always have at least the minimum width if player has any score
        if playerEntry.currentScore > 0 {
            return max(minimumWidth, calculatedWidth)
        } else {
            return max(minimumWidth, calculatedWidth)
        }
    }
    
    private var performanceIndicator: some View {
        let percentage = playerEntry.scoreBarWidth
        let color: Color = {
            if percentage >= 0.8 { return .gpGreen }
            else if percentage >= 0.5 { return .blue }
            else if percentage >= 0.25 { return .orange }
            else { return .red }
        }()
        
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(0.7)
    }
    
    /// Original score bar colors (back to .gpGreen and blue)
    private var originalScoreBarColor: Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen }        // Elite - Green
        else if percentage >= 0.5 { return .blue }       // Good - Blue  
        else if percentage >= 0.25 { return .orange }    // Okay - Orange
        else { return .red }                             // Poor - Red
    }
    
    private var scoreBarColor: Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen.opacity(0.5) }
        else if percentage >= 0.5 { return .blue.opacity(0.4) }
        else if percentage >= 0.25 { return .orange.opacity(0.4) }
        else { return .red.opacity(0.3) }
    }
    
    private var positionColor: Color {
        switch playerEntry.position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
    
    private var leagueSourceColor: Color {
        switch playerEntry.leagueSource {
        case "Sleeper": return .blue
        case "ESPN": return .red
        default: return .gray
        }
    }
    
    private var playerScoreColor: Color {
        let matchup = playerEntry.matchup
        
        if matchup.isChoppedLeague {
            // For Chopped leagues, use elimination status
            guard let ranking = matchup.myTeamRanking else { return .gpGreen }
            
            switch ranking.eliminationStatus {
            case .champion, .safe:
                return .gpGreen
            case .warning:
                return .gpYellow
            case .danger:
                return .orange
            case .critical, .eliminated:
                return .gpRedPink
            }
        } else {
            // For regular fantasy matchups, use the same logic as MatchupsHub
            guard let myTeam = matchup.myTeam,
                  let opponentTeam = matchup.opponentTeam else {
                return .gpGreen
            }
            
            let myScore = myTeam.currentScore ?? 0
            let opponentScore = opponentTeam.currentScore ?? 0
            let isWinning = myScore > opponentScore
            
            return isWinning ? .gpGreen : .gpRedPink
        }
    }
    
    private var formattedPlayerName: String {
        let shortName = playerEntry.player.shortName
        
        // Check if it's in "First Last" format and first name is single letter
        let components = shortName.split(separator: " ")
        if components.count >= 2 {
            let firstName = String(components[0])
            let lastName = components[1...]
            
            // If first name is single character, add period
            if firstName.count == 1 {
                return firstName + ". " + lastName.joined(separator: " ")
            }
        }
        
        return shortName
    }
    
    // MARK: - Stat Breakdown Methods
    
    /// Format player stat breakdown based on position using centralized stats
    private func formatPlayerStatBreakdown() -> String? {
        let playerName = playerEntry.player.fullName
        
        guard viewModel.statsLoaded else {
            return nil
        }
        
        guard let sleeperPlayer = getSleeperPlayerData() else {
            return nil
        }
        
        guard let stats = viewModel.playerStats[sleeperPlayer.playerID] else {
            return nil
        }
        
        let position = playerEntry.position
        var breakdown: [String] = []
        
        switch position {
        case "QB":
            // Passing stats: completions/attempts, yards, TDs
            if let attempts = stats["pass_att"], attempts > 0 {
                let completions = stats["pass_cmp"] ?? 0
                let yards = stats["pass_yd"] ?? 0
                let tds = stats["pass_td"] ?? 0
                breakdown.append("\(Int(completions))/\(Int(attempts)) CMP")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) PASS TD") }
            } else {
                // 🔥 NEW: Fallback for QBs with no detailed stats - show fantasy points breakdown
                if let pprPoints = stats["pts_ppr"], pprPoints > 0 {
                    breakdown.append("\(String(format: "%.1f", pprPoints)) PPR PTS")
                } else if let halfPprPoints = stats["pts_half_ppr"], halfPprPoints > 0 {
                    breakdown.append("\(String(format: "%.1f", halfPprPoints)) HALF PPR PTS")
                } else if let stdPoints = stats["pts_std"], stdPoints > 0 {
                    breakdown.append("\(String(format: "%.1f", stdPoints)) STD PTS")
                }
            }
            
            // Rushing stats if significant for QBs
            if let carries = stats["rush_att"], carries > 0 {
                let rushYards = stats["rush_yd"] ?? 0
                let rushTds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if rushYards > 0 { breakdown.append("\(Int(rushYards)) RUSH YD") }
                if rushTds > 0 { breakdown.append("\(Int(rushTds)) RUSH TD") }
            }
            
        case "RB":
            // Rushing stats: carries, yards, TDs
            if let carries = stats["rush_att"], carries > 0 {
                let yards = stats["rush_yd"] ?? 0
                let tds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
            } else {
                // 🔥 NEW: Fallback for RBs with no detailed stats
                if let pprPoints = stats["pts_ppr"], pprPoints > 0 {
                    breakdown.append("\(String(format: "%.1f", pprPoints)) PPR PTS")
                }
            }
            // Receiving if significant
            if let receptions = stats["rec"], receptions > 0 {
                let recYards = stats["rec_yd"] ?? 0
                let recTds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions)) REC")
                if recYards > 0 { breakdown.append("\(Int(recYards)) REC YD") }
                if recTds > 0 { breakdown.append("\(Int(recTds)) REC TD") }
            }
            
        case "WR", "TE":
            // Receiving stats: receptions/targets, yards, TDs
            if let receptions = stats["rec"], receptions > 0 {
                let targets = stats["rec_tgt"] ?? receptions
                let yards = stats["rec_yd"] ?? 0
                let tds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
            } else {
                // 🔥 NEW: Fallback for WR/TE with no detailed stats
                if let pprPoints = stats["pts_ppr"], pprPoints > 0 {
                    breakdown.append("\(String(format: "%.1f", pprPoints)) PPR PTS")
                }
            }
            // Rushing if significant for WRs
            if position == "WR", let rushYards = stats["rush_yd"], rushYards > 0 {
                breakdown.append("\(Int(rushYards)) RUSH YD")
            }
            
        case "K":
            // Field goals and extra points
            if let fgMade = stats["fgm"], fgMade > 0 {
                let fgAtt = stats["fga"] ?? fgMade
                breakdown.append("\(Int(fgMade))/\(Int(fgAtt)) FG")
            }
            if let xpMade = stats["xpm"], xpMade > 0 {
                breakdown.append("\(Int(xpMade)) XP")
            }
            
            // 🔥 NEW: Fallback for kickers with no detailed stats
            if breakdown.isEmpty, let pprPoints = stats["pts_ppr"], pprPoints > 0 {
                breakdown.append("\(String(format: "%.1f", pprPoints)) PTS")
            }
            
        case "DEF", "DST":
            // Defense stats: sacks, interceptions, fumble recoveries
            if let sacks = stats["def_sack"], sacks > 0 {
                breakdown.append("\(Int(sacks)) SACK")
            }
            if let ints = stats["def_int"], ints > 0 {
                breakdown.append("\(Int(ints)) INT")
            }
            if let fumRec = stats["def_fum_rec"], fumRec > 0 {
                breakdown.append("\(Int(fumRec)) FUM REC")
            }
            
            // 🔥 NEW: Fallback for defense with no detailed stats
            if breakdown.isEmpty, let pprPoints = stats["pts_ppr"], pprPoints > 0 {
                breakdown.append("\(String(format: "%.1f", pprPoints)) PTS")
            }
            
        default:
            return nil
        }
        
        let result = breakdown.isEmpty ? nil : breakdown.joined(separator: ", ")
        return result
    }
    
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = playerEntry.player.fullName
        
        // Find all potential matches first
        let potentialMatches = playerDirectory.players.values.filter { sleeperPlayer in
            if sleeperPlayer.fullName.lowercased() == playerName.lowercased() {
                return true
            }
            
            if sleeperPlayer.shortName.lowercased() == playerEntry.player.shortName.lowercased() &&
               sleeperPlayer.team?.lowercased() == playerEntry.player.team?.lowercased() {
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
        
        // If multiple matches, use a robust prioritization system
        if potentialMatches.count > 1 {
            // Priority 1: Player with detailed game stats (passing, rushing, receiving, etc.)
            let detailedStatsMatches = potentialMatches.filter { player in
                if let stats = viewModel.playerStats[player.playerID] {
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
                return viewModel.playerStats[player.playerID] != nil
            }
            
            if !anyStatsMatches.isEmpty {
                return anyStatsMatches.first
            }
            
            // Priority 3: Player with most recent/current team match
            let teamMatches = potentialMatches.filter { player in
                return player.team?.lowercased() == playerEntry.player.team?.lowercased()
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