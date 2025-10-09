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
    @StateObject private var watchService = PlayerWatchService.shared
    
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
                    
                    // Score info and watch button row
                    HStack(spacing: 8) {
                        // Watch toggle button
                        Button(action: toggleWatch) {
                            Image(systemName: isWatching ? "eye.fill" : "eye")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isWatching ? .gpOrange : .gray)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(isWatching ? Color.gpOrange.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(y: -20) // Smaller offset to align with points without disappearing
                        
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
    
    // MARK: - Watch Functionality
    
    private var isWatching: Bool {
        watchService.isWatching(playerEntry.player.id)
    }
    
    private func toggleWatch() {
        if isWatching {
            watchService.unwatchPlayer(playerEntry.player.id)
        } else {
            // Create opponent references from the matchup context
            let opponentRefs = createOpponentReferences()
            
            // Convert LivePlayerEntry to OpponentPlayer for watching
            let opponentPlayer = OpponentPlayer(
                id: UUID().uuidString,
                player: playerEntry.player,
                isStarter: playerEntry.isStarter,
                currentScore: playerEntry.currentScore,
                projectedScore: playerEntry.projectedScore,
                threatLevel: .moderate, // Default threat level for personal players
                matchupAdvantage: .neutral, // Neutral advantage for personal players
                percentageOfOpponentTotal: 0.0 // Not applicable for personal players
            )
            
            let success = watchService.watchPlayer(opponentPlayer, opponentReferences: opponentRefs)
            if !success {
                // TODO: Show alert about watch limit or other issues
                print("Failed to watch player - possibly at limit")
            }
        }
    }
    
    private func createOpponentReferences() -> [OpponentReference] {
        // For All Live Players, we're watching our own players, so create a reference
        // indicating this is for personal roster tracking
        return [OpponentReference(
            id: "personal_roster_\(playerEntry.matchup.id)",
            opponentName: "Personal Roster",
            leagueName: playerEntry.leagueName,
            leagueSource: playerEntry.leagueSource.lowercased()
        )]
    }
    
    // MARK: - ADD: Score Breakdown Helper Methods
    
    /// Creates score breakdown from current player stats - UNIFIED WITH FantasyPlayerCard
    private func createScoreBreakdown() -> PlayerScoreBreakdown? {
        print("🐛 DEBUG: PlayerScoreBarCardContentView createScoreBreakdown called")
        
        guard let sleeperPlayer = getSleeperPlayerData() else {
            print("🐛 DEBUG: No sleeperPlayer data")
            return nil
        }
        
        // Get stats from AllLivePlayersViewModel (same as FantasyPlayerCard)
        guard let stats = viewModel.playerStats[sleeperPlayer.playerID],
              !stats.isEmpty else {
            print("🐛 DEBUG: No player stats found")
            return nil
        }
        
        print("🐛 DEBUG: Found \(stats.count) player stats")
        
        // Convert LivePlayerEntry to FantasyPlayer for breakdown (same as before)
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
        
        // 🔥 NEW: Use standardized ScoreBreakdownFactory interface (SAME AS FantasyPlayerCard)
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        // 🔥 CRITICAL FIX: Try to find the actual league context like FantasyPlayerCard does
        var leagueContext: LeagueContext? = nil
        var leagueName: String? = nil
        
        // Try to get the league from the matchup's league info
        let matchupLeague = playerEntry.matchup.league
        let leagueID = matchupLeague.league.id
        let source: LeagueSource = playerEntry.leagueSource.uppercased() == "ESPN" ? .espn : .sleeper
        
        // 🔥 CRITICAL DEBUG: Log what we're trying to find
        print("🎯 SCORING DEBUG: League ID: \(leagueID)")
        print("🎯 SCORING DEBUG: Source: \(source)")
        print("🎯 SCORING DEBUG: League Name: \(playerEntry.leagueName)")
        
        // 🔥 CRITICAL FIX: Try to find scoring settings directly from the league object first
        var customScoringSettings: [String: Double]? = nil
        
        if source == .espn, let espnLeague = matchupLeague.league as? ESPNLeague {
            // Extract scoring settings directly from the league object
            if let scoringSettings = espnLeague.scoringSettings,
               let scoringItems = scoringSettings.scoringItems {
                print("🎯 SCORING DIRECT: Found ESPN scoring settings in league object (\(scoringItems.count) items)")
                
                var directSettings: [String: Double] = [:]
                for item in scoringItems {
                    guard let statId = item.statId, let points = item.points else { continue }
                    if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                        if points != 0.0 {
                            directSettings[sleeperKey] = points
                        }
                    }
                }
                
                if !directSettings.isEmpty {
                    customScoringSettings = directSettings
                    print("🎯 SCORING DIRECT: Extracted \(directSettings.count) scoring rules directly from league")
                    print("🎯 SCORING DIRECT: Sample rules: \(Array(directSettings.prefix(5)))")
                }
            }
        } else if source == .sleeper, let sleeperLeague = matchupLeague.league as? SleeperLeague {
            // Extract scoring settings directly from Sleeper league object
            if let sleeperScoringSettings = sleeperLeague.scoringSettings, !sleeperScoringSettings.isEmpty {
                customScoringSettings = sleeperScoringSettings
                print("🎯 SCORING DIRECT: Found Sleeper scoring settings in league object (\(sleeperScoringSettings.count) rules)")
            }
        }
        
        // 🔥 FALLBACK: Try ScoringSettingsManager if direct extraction failed
        if customScoringSettings == nil {
            if let managerSettings = ScoringSettingsManager.shared.getScoringSettings(for: leagueID, source: source) {
                customScoringSettings = managerSettings
                print("🎯 SCORING FALLBACK: Found settings in ScoringSettingsManager (\(managerSettings.count) rules)")
            } else {
                print("🎯 SCORING FALLBACK: NO settings found in ScoringSettingsManager")
            }
        }
        
        leagueContext = LeagueContext(
            leagueID: leagueID,
            source: source,
            isChopped: playerEntry.matchup.isChoppedLeague,
            customScoringSettings: customScoringSettings // 🔥 CRITICAL: Pass the direct scoring settings
        )
        leagueName = playerEntry.leagueName
        
        print("🔥 DEBUG: Using unified scoring - League: \(playerEntry.leagueName), Source: \(source)")
        print("🔥 DEBUG: Custom scoring settings: \(customScoringSettings?.count ?? 0) rules")
        
        // 🔥 CRITICAL: Use same exact interface as FantasyPlayerCard
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: fantasyPlayer,
            week: selectedWeek,
            localStatsProvider: nil, // Stats will be found via StatsFacade -> AllLivePlayersViewModel
            leagueContext: leagueContext
        )
        
        // 🔥 NEW: Add league name to breakdown (same as FantasyPlayerCard)
        let finalBreakdown = leagueName != nil ? breakdown.withLeagueName(leagueName!) : breakdown
        
        print("🔥 DEBUG: Created breakdown with hasRealScoringData: \(finalBreakdown.hasRealScoringData)")
        print("🔥 DEBUG: Breakdown total: \(finalBreakdown.totalScore)")
        print("🔥 DEBUG: Breakdown items: \(finalBreakdown.items.count)")
        
        return finalBreakdown
    }
    
    /// Creates empty breakdown for players with no stats - SAME AS FantasyPlayerCard
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
            isChoppedLeague: playerEntry.matchup.isChoppedLeague
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
