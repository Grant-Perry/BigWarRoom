//
//  PlayerScoreBarCardContentView.swift
//  BigWarRoom
//
//  Main content view for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardContentView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let scoreBarWidth: Double
    let cardHeight: Double
    let formattedPlayerName: String
    let playerScoreColor: Color
    
    @ObservedObject var viewModel: AllLivePlayersViewModel
    
    @State private var showingScoreBreakdown = false
    
    var body: some View {
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
                        PlayerScoreBarCardLeagueBannerView(playerEntry: playerEntry)
                        PlayerScoreBarCardPositionBadgeView(playerEntry: playerEntry)
                    }
                    
                    Spacer() // Push score to bottom of this section
                    
                    // Score info - UPDATED: Make tappable for score breakdown
                    HStack(spacing: 8) {
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 8) {
                                // UPDATED: Make score tappable
                                Button(action: {
                                    showingScoreBreakdown = true
                                }) {
                                    Text(playerEntry.currentScoreString)
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .foregroundColor(playerScoreColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                .padding(-2)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
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
            .background(
                PlayerScoreBarCardBackgroundView(
                    playerEntry: playerEntry,
                    scoreBarWidth: scoreBarWidth
                )
            )
            
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
                    // 🔥 NEW: Use TeamCodeNormalizer for consistent team mapping
                    let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
                    
                    if let team = NFLTeam.team(for: normalizedTeamCode) {
                        TeamAssetManager.shared.logoOrFallback(for: team.id)
                            .frame(width: 140, height: 140)
                            .opacity(0.25)
                            .offset(x: 10, y: -5) // 🔥 FIXED: Back to x: 20 as requested
                            .zIndex(0)
                    } else {
                        let _ = print("🔍 DEBUG - No team logo for player: \(playerEntry.player.shortName), team: '\(teamCode)' (normalized: '\(normalizedTeamCode)')")
                    }
                    
                    // Player image in front - FIXED HEIGHT
                    PlayerScoreBarCardPlayerImageView(playerEntry: playerEntry)
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
        .sheet(isPresented: $showingScoreBreakdown) {
            if let breakdown = createScoreBreakdown() {
                ScoreBreakdownView(breakdown: breakdown)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            } else {
                ScoreBreakdownView(breakdown: createEmptyBreakdown())
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - ADD: Score Breakdown Helper Methods
    
    /// Creates score breakdown from current player stats
    private func createScoreBreakdown() -> PlayerScoreBreakdown? {
        guard let sleeperPlayer = getSleeperPlayerData() else {
            return nil
        }
        
        // Get stats from viewModel
        guard let stats = viewModel.playerStats[sleeperPlayer.playerID],
              !stats.isEmpty else {
            return nil
        }
        
        // 🔥 NEW: Debug Josh Allen specifically
        if playerEntry.player.fullName.contains("Josh Allen") {
            print("🎯 JOSH ALLEN STATS DEBUG:")
            print("   League: \(playerEntry.leagueName)")
            print("   Score: \(playerEntry.currentScore)")
            print("   Sleeper ID: \(sleeperPlayer.playerID)")
            print("   Stats count: \(stats.count)")
            
            // Show key stats
            let keyStats = ["pass_yd", "pass_td", "pass_int", "rush_yd", "rush_td", "rec", "rec_yd", "pts_ppr", "pts_std"]
            for statKey in keyStats {
                if let value = stats[statKey], value > 0 {
                    print("     \(statKey): \(value)")
                }
            }
        }
        
        // Convert LivePlayerEntry to FantasyPlayer for breakdown
        let fantasyPlayer = FantasyPlayer(
            id: playerEntry.id,
            sleeperID: sleeperPlayer.playerID,
            espnID: playerEntry.player.espnID,
            firstName: playerEntry.player.firstName,
            lastName: playerEntry.player.lastName,
            position: playerEntry.position,
            team: playerEntry.player.team,
            jerseyNumber: playerEntry.player.jerseyNumber,
            currentPoints: playerEntry.currentScore,
            projectedPoints: playerEntry.projectedScore,
            gameStatus: nil,
            isStarter: true,
            lineupSlot: playerEntry.position
        )
        
        // 🔥 FIXED: Create consistent league context
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        let leagueID = playerEntry.matchup.league.league.id
        let source: LeagueSource = playerEntry.leagueSource.uppercased() == "ESPN" ? .espn : .sleeper
        
        print("🎯 DEBUG: Creating score breakdown for \(fantasyPlayer.fullName)")
        print("   League: \(playerEntry.leagueName) (ID: \(leagueID))")
        print("   Source: \(source)")
        print("   Score: \(playerEntry.currentScore)")
        
        let leagueContext = LeagueContext(
            leagueID: leagueID,
            source: source,
            isChopped: playerEntry.matchup.isChoppedLeague,
            customScoringSettings: nil
        )
        
        // Use standardized breakdown factory
        return ScoreBreakdownFactory.createBreakdown(
            for: fantasyPlayer,
            week: selectedWeek,
            localStatsProvider: nil, // AllLivePlayersViewModel will be used via StatsFacade
            leagueContext: leagueContext
        ).withLeagueName(playerEntry.leagueName) // 🔥 NEW: Add league name
    }
    
    /// Creates empty breakdown for players with no stats
    private func createEmptyBreakdown() -> PlayerScoreBreakdown {
        // Convert LivePlayerEntry to FantasyPlayer
        let fantasyPlayer = FantasyPlayer(
            id: playerEntry.id,
            sleeperID: nil,
            espnID: playerEntry.player.espnID,
            firstName: playerEntry.player.firstName,
            lastName: playerEntry.player.lastName,
            position: playerEntry.position,
            team: playerEntry.player.team,
            jerseyNumber: playerEntry.player.jerseyNumber,
            currentPoints: playerEntry.currentScore,
            projectedPoints: playerEntry.projectedScore,
            gameStatus: nil,
            isStarter: true,
            lineupSlot: playerEntry.position
        )
        
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        return PlayerScoreBreakdown(
            player: fantasyPlayer,
            week: selectedWeek,
            items: [],
            totalScore: playerEntry.currentScore,
            isChoppedLeague: false // All Live Players - not chopped
        )
    }
    
    // MARK: - Stat Breakdown Methods (moved from main file)
    
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
    
    // MARK: - Player Matching Logic (moved from main file)
    
    // 🔥 PERFORMANCE: Use PlayerMatchService instead of O(n) scans
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = playerEntry.player.fullName
        let shortName = playerEntry.player.shortName
        let team = playerEntry.player.team
        let position = playerEntry.position.uppercased()
        
        // 🔥 NEW: Use high-performance PlayerMatchService - specify which overload to use
        return PlayerMatchService.shared.matchPlayer(
            fullName: playerName,
            shortName: shortName,
            team: team,
            position: position
        )
    }
}