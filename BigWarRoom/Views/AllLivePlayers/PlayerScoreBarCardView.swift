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
    private let cardHeight: Double = 110.0 // Increased card height to accommodate stats at bottom (was 95.0)
    private let scoreBarHeight: Double = 20.0 // Shorter score bar (was 23.3)
    private let scoreBarOpacity: Double = 0.35 // Score bar transparency
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            // Just the player card - no separate scoreBar
            playerCardView
        }
        .buttonStyle(PlainButtonStyle())
        .id(playerEntry.id) // Force view refresh
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
                
                // Center matchup section
                VStack {
                    Spacer()
                    MatchupTeamFinalView(player: playerEntry.player)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .offset(x: 37)
                .scaleEffect(1.1)
                
                // Player info - moved to right side with swapped league banner and player name
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Spacer()
                        
                        // Player name moved to top (no position badge here)
                        Text(formattedPlayerName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    HStack(spacing: 6) {
                        Spacer()
                        
                        // League banner and position badge on same line (swapped order)
                        leagueBanner
                        positionBadge
                    }
                    
                    Spacer() // Push score to bottom of this section
                    
                    // Score info - simplified without matchup info
                    HStack(spacing: 8) {
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(playerEntry.currentScoreString)
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundColor(playerScoreColor)
                                
                                Text("pts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .offset(y: -20)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(teamBackgroundView)
            
            // Stats section spanning the entire bottom - ONLY show if player has fantasy points > 0
            if playerEntry.currentScore > 0, let statLine = formatPlayerStatBreakdown() {
                VStack {
                    Spacer()
                    HStack {
                        Text(statLine)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            
            // NOW overlay the player image on top - unconstrained!
            HStack {
                ZStack {
                    // 🔥 FIXED: Large floating team logo behind player - positioned further right
                    let teamCode = playerEntry.player.team ?? ""
                    let mappedTeamCode = teamCode == "WSH" ? "WAS" : teamCode // Map WSH to WAS
                    
                    if let team = NFLTeam.team(for: mappedTeamCode) {
                        TeamAssetManager.shared.logoOrFallback(for: team.id)
                            .frame(width: 140, height: 140)
                            .opacity(0.25)
                            .offset(x: 10, y: -5) // 🔥 FIXED: Back to x: 20 as requested
                            .zIndex(0)
                    } else {
                        let _ = print("🔍 DEBUG - No team logo for player: \(playerEntry.player.shortName), team: '\(teamCode)' (mapped: '\(mappedTeamCode)')")
                    }
                    
                    // Player image in front - FIXED HEIGHT
                    playerImageView
                        .zIndex(1)
                        .offset(x: -50) // 🔥 NEW: Move player left to clip off shoulder
                }
                .frame(height: 80) // Constrain height
                .frame(maxWidth: 180) // 🔥 INCREASED: Wider to accommodate offset logo (was 120)
                .offset(x: -10)
                Spacer()
            }
        }
        .frame(height: cardHeight) // Apply the card height constraint
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip the entire thing
    }
    
    // MARK: - Subviews
    
    private var playerImageView: some View {
        AsyncImage(url: playerEntry.player.headshotURL) { phase in
            switch phase {
            case .empty:
                // Loading state
                playerFallbackView
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            case .success(let image):
                // Successfully loaded image
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                // Failed to load - try alternative URL or show fallback
                AsyncImage(url: alternativeImageURL) { altPhase in
                    switch altPhase {
                    case .success(let altImage):
                        altImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        playerFallbackView
                    }
                }
            @unknown default:
                playerFallbackView
            }
        }
        .frame(width: 80, height: 100)
        .id(playerEntry.player.id + "_" + (playerEntry.player.headshotURL?.absoluteString ?? "")) // Force refresh when URL changes
    }
    
    /// Alternative image URL for retry logic
    private var alternativeImageURL: URL? {
        // Try ESPN headshot as fallback
        if let espnURL = playerEntry.player.espnHeadshotURL {
            return espnURL
        }
        
        // For defense/special teams, try a different approach
        if playerEntry.position == "DEF" || playerEntry.position == "DST" {
            if let team = playerEntry.player.team {
                // Try ESPN team logo as player image for defenses
                return URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")
            }
        }
        
        return nil
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
                // 🔥 DEBUG: Print when small logo fails too
                let _ = print("🔍 DEBUG - No small team logo for: \(playerEntry.player.shortName), team: '\(playerEntry.player.team ?? "nil")'")
                Circle()
                    .fill(leagueSourceColor)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var leagueBanner: some View {
        HStack(spacing: 4) {
            // 🔥 DEBUG: Add logging to see actual leagueSource values
            Group {
                let leagueSourceValue = playerEntry.leagueSource
                let _ = print("🔍 DEBUG - League source: '\(leagueSourceValue)' (lowercased: '\(leagueSourceValue.lowercased())') for league: '\(playerEntry.leagueName)'")
                
                switch leagueSourceValue.lowercased() {
                case "espn":
                    Image("espnLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)  // 50% smaller (was 24x24)
                case "sleeper":
                    Image("sleeperLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)  // 50% smaller (was 24x24)
                default:
                    // 🔥 DEBUG: Log when falling back to circle
                    let _ = print("❌ FALLBACK - Unknown league source: '\(leagueSourceValue)' - using circle fallback")
                    Circle()
                        .fill(leagueSourceColor)
                        .frame(width: 6, height: 6)
                }
            }
            
            Text(playerEntry.leagueName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
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
    
    private var playerCardGradColor: Color {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.primaryColor
        }
        return .nyyDark // Fallback to original color if no team found
    }
    
    private var teamBackgroundView: some View {
        ZStack {
            // BASE TEAM BACKGROUND - Applied to ALL cards
            ZStack {
                // MAIN GRADIENT BACKGROUND - Team colored base for all cards
                LinearGradient(
                    gradient: Gradient(colors: [
                        playerCardGradColor.opacity(0.9), // STRONGER opacity
                        Color.black.opacity(0.7),
                        playerCardGradColor.opacity(0.8) // STRONGER opacity
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // SUBTLE OVERLAY PATTERN
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        playerCardGradColor.opacity(0.1) // Add more team color tint
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // SCORE BAR OVERLAY - Only for players with points
            if playerEntry.currentScore > 0 {
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
            
            // Only show performance indicator if player has points
            if playerEntry.currentScore > 0 {
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
        if percentage >= 0.8 { return .gpGreen.opacity(scoreBarOpacity) }        // Elite - Green
        else if percentage >= 0.5 { return .blue.opacity(scoreBarOpacity) }       // Good - Blue  
        else if percentage >= 0.25 { return .orange.opacity(scoreBarOpacity) }    // Okay - Orange
        else { return .red.opacity(scoreBarOpacity) }                             // Poor - Red
    }
    
    private var scoreBarColor: Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen.opacity(0.4) }
        else if percentage >= 0.5 { return .blue.opacity(0.3) }
        else if percentage >= 0.25 { return .orange.opacity(0.3) }
        else { return .red.opacity(0.2) }
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
        // 🔥 FIXED: Use full name instead of short name initials
        let fullName = playerEntry.player.fullName
        
        // Check if it's in "First Last" format and first name is single letter in shortName
        let shortName = playerEntry.player.shortName
        let shortComponents = shortName.split(separator: " ")
        
        if shortComponents.count >= 2 {
            let firstName = String(shortComponents[0])
            
            // If short name uses single character, but we have full name, use full name
            if firstName.count == 1 && !fullName.isEmpty {
                return fullName
            }
            
            // If first name is single character in short name, add period to short name
            if firstName.count == 1 {
                let lastName = shortComponents[1...]
                return firstName + ". " + lastName.joined(separator: " ")
            }
        }
        
        // Default to full name if available, otherwise short name
        return !fullName.isEmpty ? fullName : shortName
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
    
    // 🔥 BULLETPROOF: Enhanced player matching with comprehensive debug logging and multiple fallback strategies
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = playerEntry.player.fullName
        let shortName = playerEntry.player.shortName
        let team = playerEntry.player.team?.uppercased() ?? "NO_TEAM"
        let position = playerEntry.position.uppercased()
        
        // 🔥 JAMES COOK DEBUG: Special logging for James Cook to diagnose the issue
        let isJamesCook = playerName.lowercased().contains("james cook") || shortName.lowercased().contains("j. cook") || shortName.lowercased().contains("cook")
        
        if isJamesCook {
            print("🔍 JAMES COOK DEBUG - Starting match for:")
            print("   Full Name: '\(playerName)'")
            print("   Short Name: '\(shortName)'")
            print("   Team: '\(team)'")
            print("   Position: '\(position)'")
            print("   Available Sleeper players: \(playerDirectory.players.count)")
            
            // Show sample of James Cook entries in player directory
            let cookEntries = playerDirectory.players.values.filter { player in
                player.fullName.lowercased().contains("cook") || player.lastName?.lowercased().contains("cook") == true
            }
            print("   Found \(cookEntries.count) 'Cook' entries in directory:")
            for cookEntry in cookEntries.prefix(5) {
                print("     - \(cookEntry.fullName) (\(cookEntry.team ?? "NO_TEAM")) \(cookEntry.position ?? "NO_POS") ID: \(cookEntry.playerID)")
            }
        }
        
        // 🔥 STRATEGY 1: Exact match - Full name + team + position
        var exactMatches = playerDirectory.players.values.filter { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName.lowercased() &&
            sleeperPlayer.team?.uppercased() == team &&
            sleeperPlayer.position?.uppercased() == position
        }
        
        if isJamesCook {
            print("   Strategy 1 (Exact): \(exactMatches.count) matches")
        }
        
        if exactMatches.count == 1 {
            if isJamesCook { print("✅ JAMES COOK: Exact match found - \(exactMatches.first!.fullName)") }
            return exactMatches.first
        }
        
        // 🔥 STRATEGY 2: Short name match - Short name + team + position
        var shortNameMatches = playerDirectory.players.values.filter { sleeperPlayer in
            sleeperPlayer.shortName.lowercased() == shortName.lowercased() &&
            sleeperPlayer.team?.uppercased() == team &&
            sleeperPlayer.position?.uppercased() == position
        }
        
        if isJamesCook {
            print("   Strategy 2 (Short Name): \(shortNameMatches.count) matches")
        }
        
        if shortNameMatches.count == 1 {
            if isJamesCook { print("✅ JAMES COOK: Short name match found - \(shortNameMatches.first!.fullName)") }
            return shortNameMatches.first
        }
        
        // 🔥 STRATEGY 3: Last name + team + position (for cases like "James Cook" vs "J. Cook")
        let lastName = extractLastName(from: playerName)
        var lastNameMatches = playerDirectory.players.values.filter { sleeperPlayer in
            let sleeperLastName = sleeperPlayer.lastName?.lowercased() ?? extractLastName(from: sleeperPlayer.fullName).lowercased()
            return sleeperLastName == lastName.lowercased() &&
                   sleeperPlayer.team?.uppercased() == team &&
                   sleeperPlayer.position?.uppercased() == position
        }
        
        if isJamesCook {
            print("   Strategy 3 (Last Name '\(lastName)'): \(lastNameMatches.count) matches")
            for match in lastNameMatches {
                print("     - \(match.fullName) (\(match.team ?? "NO_TEAM")) \(match.position ?? "NO_POS")")
            }
        }
        
        if lastNameMatches.count == 1 {
            if isJamesCook { print("✅ JAMES COOK: Last name match found - \(lastNameMatches.first!.fullName)") }
            return lastNameMatches.first
        }
        
        // 🔥 STRATEGY 4: Fuzzy team matching (handle team abbreviation differences)
        let teamAliases = getTeamAliases(for: team)
        var fuzzyTeamMatches = playerDirectory.players.values.filter { sleeperPlayer in
            let sleeperTeam = sleeperPlayer.team?.uppercased() ?? ""
            return (teamAliases.contains(sleeperTeam) || sleeperTeam == team) &&
                   sleeperPlayer.position?.uppercased() == position &&
                   (sleeperPlayer.fullName.lowercased() == playerName.lowercased() ||
                    sleeperPlayer.shortName.lowercased() == shortName.lowercased() ||
                    (sleeperPlayer.lastName?.lowercased() ?? "") == lastName.lowercased())
        }
        
        if isJamesCook {
            print("   Strategy 4 (Fuzzy Team): \(fuzzyTeamMatches.count) matches")
            print("     Team aliases for \(team): \(teamAliases)")
        }
        
        if fuzzyTeamMatches.count == 1 {
            if isJamesCook { print("✅ JAMES COOK: Fuzzy team match found - \(fuzzyTeamMatches.first!.fullName)") }
            return fuzzyTeamMatches.first
        }
        
        // 🔥 STRATEGY 5: Relaxed position matching (handle FLEX, DEF vs DST, etc.)
        let positionAliases = getPositionAliases(for: position)
        var fuzzyPositionMatches = playerDirectory.players.values.filter { sleeperPlayer in
            let sleeperPosition = sleeperPlayer.position?.uppercased() ?? ""
            return (positionAliases.contains(sleeperPosition) || sleeperPosition == position) &&
                   sleeperPlayer.team?.uppercased() == team &&
                   (sleeperPlayer.fullName.lowercased() == playerName.lowercased() ||
                    sleeperPlayer.shortName.lowercased() == shortName.lowercased() ||
                    (sleeperPlayer.lastName?.lowercased() ?? "") == lastName.lowercased())
        }
        
        if isJamesCook {
            print("   Strategy 5 (Fuzzy Position): \(fuzzyPositionMatches.count) matches")
            print("     Position aliases for \(position): \(positionAliases)")
        }
        
        if fuzzyPositionMatches.count == 1 {
            if isJamesCook { print("✅ JAMES COOK: Fuzzy position match found - \(fuzzyPositionMatches.first!.fullName)") }
            return fuzzyPositionMatches.first
        }
        
        // 🔥 STRATEGY 6: Combined fuzzy matching (last resort)
        var combinedFuzzyMatches = playerDirectory.players.values.filter { sleeperPlayer in
            let sleeperTeam = sleeperPlayer.team?.uppercased() ?? ""
            let sleeperPosition = sleeperPlayer.position?.uppercased() ?? ""
            let sleeperLastName = sleeperPlayer.lastName?.lowercased() ?? extractLastName(from: sleeperPlayer.fullName).lowercased()
            
            return (teamAliases.contains(sleeperTeam) || sleeperTeam == team) &&
                   (positionAliases.contains(sleeperPosition) || sleeperPosition == position) &&
                   sleeperLastName == lastName.lowercased()
        }
        
        if isJamesCook {
            print("   Strategy 6 (Combined Fuzzy): \(combinedFuzzyMatches.count) matches")
        }
        
        // Collect all potential matches for prioritization
        var allPotentialMatches: [SleeperPlayer] = []
        allPotentialMatches.append(contentsOf: exactMatches)
        allPotentialMatches.append(contentsOf: shortNameMatches)
        allPotentialMatches.append(contentsOf: lastNameMatches)
        allPotentialMatches.append(contentsOf: fuzzyTeamMatches)
        allPotentialMatches.append(contentsOf: fuzzyPositionMatches)
        allPotentialMatches.append(contentsOf: combinedFuzzyMatches)
        
        // Remove duplicates
        let uniqueMatches = Array(Set(allPotentialMatches.map { $0.playerID })).compactMap { id in
            allPotentialMatches.first { $0.playerID == id }
        }
        
        if isJamesCook {
            print("   Total unique potential matches: \(uniqueMatches.count)")
            for match in uniqueMatches {
                print("     - \(match.fullName) (\(match.team ?? "NO_TEAM")) \(match.position ?? "NO_POS") ID: \(match.playerID)")
            }
        }
        
        // If we have matches, prioritize them
        if !uniqueMatches.isEmpty {
            // Priority 1: Player with detailed game stats
            let detailedStatsMatches = uniqueMatches.filter { player in
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
                if isJamesCook { print("✅ JAMES COOK: Using detailed stats match - \(detailedStatsMatches.first!.fullName)") }
                return detailedStatsMatches.first
            }
            
            // Priority 2: Player with jersey number match
            if let jerseyNumber = playerEntry.player.jerseyNumber {
                let jerseyMatches = uniqueMatches.filter { player in
                    return player.number?.description == jerseyNumber
                }
                if !jerseyMatches.isEmpty {
                    if isJamesCook { print("✅ JAMES COOK: Using jersey number match - \(jerseyMatches.first!.fullName)") }
                    return jerseyMatches.first
                }
            }
            
            // Priority 3: Player with any stats (even if just fantasy points)
            let anyStatsMatches = uniqueMatches.filter { player in
                return viewModel.playerStats[player.playerID] != nil
            }
            
            if !anyStatsMatches.isEmpty {
                if isJamesCook { print("✅ JAMES COOK: Using stats match - \(anyStatsMatches.first!.fullName)") }
                return anyStatsMatches.first
            }
            
            // Priority 4: Fallback to first match
            if isJamesCook { print("⚠️ JAMES COOK: Using first match fallback - \(uniqueMatches.first!.fullName)") }
            return uniqueMatches.first
        }
        
        // No matches found - this is where James Cook is failing
        if isJamesCook {
            print("❌ JAMES COOK: NO MATCHES FOUND!")
            print("   This suggests the player directory might not be loaded or James Cook has different data")
            print("   Player directory loaded: \(playerDirectory.players.count > 0)")
            print("   Stats loaded: \(viewModel.statsLoaded)")
            print("   Available stats keys: \(viewModel.playerStats.keys.count)")
        }
        
        print("❌ NO MATCH found for \(playerName) (\(team)) \(position)")
        return nil
    }
    
    // MARK: - Helper Methods for Bulletproof Matching
    
    /// Extract last name from full name
    private func extractLastName(from fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        return components.last ?? fullName
    }
    
    /// Get team aliases to handle different team abbreviations
    private func getTeamAliases(for team: String) -> [String] {
        switch team.uppercased() {
        case "BUF":
            return ["BUFFALO", "BUF"]
        case "MIA":
            return ["MIAMI", "MIA"]
        case "NE", "NEP":
            return ["NEW ENGLAND", "NE", "NEP", "PATRIOTS"]
        case "NYJ":
            return ["NEW YORK JETS", "NYJ", "JETS"]
        case "BAL":
            return ["BALTIMORE", "BAL"]
        case "CIN":
            return ["CINCINNATI", "CIN"]
        case "CLE":
            return ["CLEVELAND", "CLE"]
        case "PIT":
            return ["PITTSBURGH", "PIT"]
        case "HOU":
            return ["HOUSTON", "HOU"]
        case "IND":
            return ["INDIANAPOLIS", "IND"]
        case "JAX", "JAC":
            return ["JACKSONVILLE", "JAX", "JAC"]
        case "TEN":
            return ["TENNESSEE", "TEN"]
        case "DEN":
            return ["DENVER", "DEN"]
        case "KC":
            return ["KANSAS CITY", "KC"]
        case "LV", "LVR", "OAK":
            return ["LAS VEGAS", "LV", "LVR", "OAKLAND", "OAK", "RAIDERS"]
        case "LAC":
            return ["LOS ANGELES CHARGERS", "LAC", "SD", "SAN DIEGO"]
        case "DAL":
            return ["DALLAS", "DAL"]
        case "NYG":
            return ["NEW YORK GIANTS", "NYG", "GIANTS"]
        case "PHI":
            return ["PHILADELPHIA", "PHI"]
        case "WSH", "WAS":
            return ["WASHINGTON", "WSH", "WAS"]
        case "CHI":
            return ["CHICAGO", "CHI"]
        case "DET":
            return ["DETROIT", "DET"]
        case "GB":
            return ["GREEN BAY", "GB"]
        case "MIN":
            return ["MINNESOTA", "MIN"]
        case "ATL":
            return ["ATLANTA", "ATL"]
        case "CAR":
            return ["CAROLINA", "CAR"]
        case "NO":
            return ["NEW ORLEANS", "NO"]
        case "TB":
            return ["TAMPA BAY", "TB"]
        case "ARI":
            return ["ARIZONA", "ARI"]
        case "LAR":
            return ["LOS ANGELES RAMS", "LAR", "STL"]
        case "SEA":
            return ["SEATTLE", "SEA"]
        case "SF":
            return ["SAN FRANCISCO", "SF"]
        default:
            return [team]
        }
    }
    
    /// Get position aliases to handle different position formats
    private func getPositionAliases(for position: String) -> [String] {
        switch position.uppercased() {
        case "DEF":
            return ["DEF", "DST", "D/ST"]
        case "DST":
            return ["DEF", "DST", "D/ST"]
        case "RB":
            return ["RB", "FLEX"]
        case "WR":
            return ["WR", "FLEX"]
        case "TE":
            return ["TE", "FLEX"]
        default:
            return [position]
        }
    }
}