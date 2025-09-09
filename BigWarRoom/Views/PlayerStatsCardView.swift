//
//  PlayerStatsCardView.swift
//  BigWarRoom
//
//  Detailed player stats card with 2024 season data
//
// MARK: -> Player Stats Card

import SwiftUI

// MARK: -> Height Conversion Extension
extension String {
    /// Converts height from inches to feet and inches format
    /// E.g., "73" becomes "6' 1""
    var formattedHeight: String {
        // Check if already in feet/inches format
        if self.contains("'") || self.contains("\"") || self.contains("ft") {
            return self
        }
        
        // Try to convert from inches
        guard let totalInches = Int(self) else {
            return self // Return original if not a number
        }
        
        let feet = totalInches / 12
        let remainingInches = totalInches % 12
        
        if remainingInches == 0 {
            return "\(feet)'"
        } else {
            return "\(feet)' \(remainingInches)\""
        }
    }
}

struct PlayerStatsCardView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    @StateObject private var playerDirectory = PlayerDirectoryStore.shared
    // 🔥 FIXED: Use shared instance instead of creating new one each time
    @ObservedObject private var livePlayersViewModel = AllLivePlayersViewModel.shared
    
    // 🔥 NEW: Track loading state for this specific view
    @State private var isLoadingStats = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with player image and basic info
                playerHeaderSection
                
                // 🔥 NEW: Detailed Stats Section (above Team Depth Chart)
                detailedStatsSection
                
                // Team Depth Chart Section
                teamDepthChartSection
                
                // Player Details from Sleeper
                playerDetailsSection
                
                // Fantasy Analysis based on search rank
                fantasyAnalysisSection
            }
            .padding()
        }
        .navigationTitle(player.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .background(Color(.systemBackground))
        .task {
            // 🔥 IMPROVED: Better loading logic with proper state tracking
            if !livePlayersViewModel.statsLoaded {
                isLoadingStats = true
                await livePlayersViewModel.loadAllPlayers()
                isLoadingStats = false
            }
        }
    }
    
    // 🔥 NEW: Detailed Stats Section
    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundColor(.gpBlue)
                    
                    Text("Live Game Stats")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Week indicator
                Text("Week \(NFLWeekService.shared.currentWeek)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.gpBlue, .gpGreen], startPoint: .leading, endPoint: .trailing))
                    )
            }
            
            if livePlayersViewModel.statsLoaded && !isLoadingStats {
                if let stats = getPlayerStats() {
                    // Stats grid based on position
                    statsGridView(stats: stats)
                } else {
                    // No stats available
                    noStatsView
                }
            } else {
                // Loading state
                loadingStatsView
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.8),
                        team?.primaryColor.opacity(0.6) ?? Color.gpBlue.opacity(0.6),
                        Color.black.opacity(0.9)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle pattern overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear,
                        Color.white.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.gpBlue, team?.accentColor ?? Color.gpGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: (team?.primaryColor ?? Color.gpBlue).opacity(0.2), radius: 6, x: 0, y: 3)
    }
    
    private func statsGridView(stats: [String: Double]) -> some View {
        let position = player.position?.uppercased() ?? ""
        
        return VStack(spacing: 8) {
            // Fantasy Points Row (Always shown if available)
            if let pprPoints = stats["pts_ppr"] {
                fantasyPointsRow(pprPoints: pprPoints, stats: stats)
            }
            
            // Position-specific stats
            switch position {
            case "QB":
                quarterbackStatsView(stats: stats)
            case "RB":
                runningBackStatsView(stats: stats)
            case "WR", "TE":
                receiverStatsView(stats: stats)
            case "K":
                kickerStatsView(stats: stats)
            case "DEF", "DST":
                defenseStatsView(stats: stats)
            default:
                genericStatsView(stats: stats)
            }
        }
    }
    
    private func fantasyPointsRow(pprPoints: Double, stats: [String: Double]) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text("Fantasy Points")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 10) {
                // PPR Points (main)
                statBubble(
                    value: String(format: "%.1f", pprPoints),
                    label: "PPR PTS",
                    color: .gpGreen,
                    isLarge: true
                )
                
                // Half PPR if different
                if let halfPpr = stats["pts_half_ppr"], halfPpr != pprPoints {
                    statBubble(
                        value: String(format: "%.1f", halfPpr),
                        label: "HALF PPR",
                        color: .gpBlue
                    )
                }
                
                // Standard if different
                if let stdPts = stats["pts_std"], stdPts != pprPoints {
                    statBubble(
                        value: String(format: "%.1f", stdPts),
                        label: "STANDARD",
                        color: .orange
                    )
                }
                
                Spacer()
            }
        }
    }
    
    private func quarterbackStatsView(stats: [String: Double]) -> some View {
        VStack(spacing: 8) {
            // Passing stats
            if let passAtt = stats["pass_att"], passAtt > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Passing")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        statBubble(
                            value: "\(Int(stats["pass_cmp"] ?? 0))/\(Int(passAtt))",
                            label: "CMP/ATT",
                            color: .blue
                        )
                        statBubble(
                            value: "\(Int(stats["pass_yd"] ?? 0))",
                            label: "PASS YD",
                            color: .purple
                        )
                        statBubble(
                            value: "\(Int(stats["pass_td"] ?? 0))",
                            label: "PASS TD",
                            color: .gpGreen
                        )
                        if let passInt = stats["pass_int"], passInt > 0 {
                            statBubble(
                                value: "\(Int(passInt))",
                                label: "INTS",
                                color: .red
                            )
                        }
                        if let passFd = stats["pass_fd"], passFd > 0 {
                            statBubble(
                                value: "\(Int(passFd))",
                                label: "PASS FD",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Rushing stats (if significant)
            if let rushAtt = stats["rush_att"], rushAtt > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Rushing")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    
                    HStack(spacing: 6) {
                        statBubble(
                            value: "\(Int(rushAtt))",
                            label: "CARRIES",
                            color: .green
                        )
                        statBubble(
                            value: "\(Int(stats["rush_yd"] ?? 0))",
                            label: "RUSH YD",
                            color: .green
                        )
                        if let rushTd = stats["rush_td"], rushTd > 0 {
                            statBubble(
                                value: "\(Int(rushTd))",
                                label: "RUSH TD",
                                color: .gpGreen
                            )
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func runningBackStatsView(stats: [String: Double]) -> some View {
        VStack(spacing: 8) {
            // Rushing stats
            if let rushAtt = stats["rush_att"], rushAtt > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Rushing")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        statBubble(
                            value: "\(Int(rushAtt))",
                            label: "CARRIES",
                            color: .green
                        )
                        statBubble(
                            value: "\(Int(stats["rush_yd"] ?? 0))",
                            label: "RUSH YD",
                            color: .green
                        )
                        statBubble(
                            value: "\(Int(stats["rush_td"] ?? 0))",
                            label: "RUSH TD",
                            color: .gpGreen
                        )
                        if let rushFd = stats["rush_fd"], rushFd > 0 {
                            statBubble(
                                value: "\(Int(rushFd))",
                                label: "RUSH FD",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Receiving stats (if significant)
            if let rec = stats["rec"], rec > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Receiving")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    
                    HStack(spacing: 6) {
                        statBubble(
                            value: "\(Int(rec))",
                            label: "REC",
                            color: .purple
                        )
                        statBubble(
                            value: "\(Int(stats["rec_yd"] ?? 0))",
                            label: "REC YD",
                            color: .purple
                        )
                        if let recTd = stats["rec_td"], recTd > 0 {
                            statBubble(
                                value: "\(Int(recTd))",
                                label: "REC TD",
                                color: .gpGreen
                            )
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func receiverStatsView(stats: [String: Double]) -> some View {
        VStack(spacing: 8) {
            // Receiving stats
            if let rec = stats["rec"], rec > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Receiving")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        statBubble(
                            value: "\(Int(rec))/\(Int(stats["rec_tgt"] ?? rec))",
                            label: "REC/TGT",
                            color: .purple
                        )
                        statBubble(
                            value: "\(Int(stats["rec_yd"] ?? 0))",
                            label: "REC YD",
                            color: .purple
                        )
                        statBubble(
                            value: "\(Int(stats["rec_td"] ?? 0))",
                            label: "REC TD",
                            color: .gpGreen
                        )
                        if let recFd = stats["rec_fd"], recFd > 0 {
                            statBubble(
                                value: "\(Int(recFd))",
                                label: "REC FD",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Rushing stats (if significant for WRs)
            if player.position?.uppercased() == "WR", let rushYd = stats["rush_yd"], rushYd > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Rushing")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    
                    HStack(spacing: 6) {
                        statBubble(
                            value: "\(Int(stats["rush_att"] ?? 0))",
                            label: "CARRIES",
                            color: .green
                        )
                        statBubble(
                            value: "\(Int(rushYd))",
                            label: "RUSH YD",
                            color: .green
                        )
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func kickerStatsView(stats: [String: Double]) -> some View {
        HStack(spacing: 12) {
            if let fgm = stats["fgm"], fgm > 0 {
                statBubble(
                    value: "\(Int(fgm))/\(Int(stats["fga"] ?? fgm))",
                    label: "FIELD GOALS",
                    color: .yellow
                )
            }
            if let xpm = stats["xpm"], xpm > 0 {
                statBubble(
                    value: "\(Int(xpm))",
                    label: "EXTRA PTS",
                    color: .orange
                )
            }
            Spacer()
        }
    }
    
    private func defenseStatsView(stats: [String: Double]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            if let sacks = stats["def_sack"], sacks > 0 {
                statBubble(
                    value: "\(Int(sacks))",
                    label: "SACKS",
                    color: .red
                )
            }
            if let ints = stats["def_int"], ints > 0 {
                statBubble(
                    value: "\(Int(ints))",
                    label: "INTS",
                    color: .red
                )
            }
            if let fumRec = stats["def_fum_rec"], fumRec > 0 {
                statBubble(
                    value: "\(Int(fumRec))",
                    label: "FUM REC",
                    color: .red
                )
            }
        }
    }
    
    private func genericStatsView(stats: [String: Double]) -> some View {
        VStack(spacing: 8) {
            Text("Limited stats available")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func statBubble(value: String, label: String, color: Color, isLarge: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(isLarge ? .callout : .caption)
                .fontWeight(.black)
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, isLarge ? 12 : 8)
        .padding(.vertical, isLarge ? 8 : 6)
        .background(
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: isLarge ? 10 : 6)
                    .fill(color.opacity(0.8))
                    .blur(radius: 1)
                
                // Main background
                RoundedRectangle(cornerRadius: isLarge ? 8 : 5)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: isLarge ? 8 : 5)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
        .scaleEffect(isLarge ? 1.03 : 1.0)
    }
    
    private var noStatsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No live stats available")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
            
            Text("Player may not be in an active game this week")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
    
    private var loadingStatsView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.0)
            
            Text("Loading live stats...")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 12)
    }
    
    private func getPlayerStats() -> [String: Double]? {
        // Try to match player with stats data
        let playerName = player.fullName.lowercased()
        
        // Find all potential matches
        let potentialMatches = playerDirectory.players.values.filter { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == player.shortName.lowercased() &&
             sleeperPlayer.team?.lowercased() == player.team?.lowercased())
        }
        
        // Find the one with stats
        for match in potentialMatches {
            if let stats = livePlayersViewModel.playerStats[match.playerID] {
                return stats
            }
        }
        
        return nil
    }
    
    // MARK: -> Team Depth Chart Section
    
    private var teamDepthChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Team Depth Chart")
                    .font(.headline)
                
                Spacer()
                
                if let team = team {
                    HStack(spacing: 6) {
                        teamAssets.logoOrFallback(for: team.id)
                            .frame(width: 20, height: 20)
                        
                        Text(team.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Get team players organized by position
            let teamPlayers = getTeamPlayers()
            
            if teamPlayers.isEmpty {
                Text("No depth chart data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(["QB", "RB", "WR", "TE", "K", "DEF"], id: \.self) { position in
                        if let positionPlayers = teamPlayers[position], !positionPlayers.isEmpty {
                            positionGroupView(position: position, players: positionPlayers)
                        }
                    }
                }
            }
        }
        .padding()
        .background(team?.backgroundColor ?? Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(team?.borderColor ?? Color.clear, lineWidth: 1)
        )
    }
    
    private func positionGroupView(position: String, players: [SleeperPlayer]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Position header
            HStack {
                Text(position)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(positionColorFor(position))
                
                Spacer()
                
                Text("\(players.count) players")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Players in this position
            VStack(spacing: 2) {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, positionPlayer in
                    depthChartPlayerRow(
                        player: positionPlayer, 
                        depth: index + 1,
                        isCurrentPlayer: positionPlayer.playerID == player.playerID
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func depthChartPlayerRow(player: SleeperPlayer, depth: Int, isCurrentPlayer: Bool) -> some View {
        HStack(spacing: 14) {
            // Enhanced depth position number with gradient
            ZStack {
                // Glow effect behind number
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                depthCircleColor(depth).opacity(0.8),
                                depthCircleColor(depth).opacity(0.3)
                            ]),
                            center: .center,
                            startRadius: 2,
                            endRadius: 15
                        )
                    )
                    .frame(width: 28, height: 28)
                    .blur(radius: 1)
                
                // Main circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                depthCircleColor(depth),
                                depthCircleColor(depth).opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: depthCircleColor(depth).opacity(0.4), radius: 3, x: 0, y: 2)
                
                Text("\(depth)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
            }
            
            // Enhanced player headshot with glow
            ZStack {
                // Position-colored glow behind image
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                positionColorFor(player.position ?? "").opacity(0.6),
                                positionColorFor(player.position ?? "").opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .blur(radius: 2)
                
                PlayerImageView(
                    player: player,
                    size: 34,
                    team: team
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),
                                    positionColorFor(player.position ?? "").opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            }
            
            // Enhanced player info section
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(player.shortName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isCurrentPlayer ? .white : .primary)
                    
                    if let number = player.number {
                        Text("#\(number)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.8))
                            )
                    }
                    
                    Spacer()
                    
                    // Enhanced fantasy rank with styling
                    if let searchRank = player.searchRank {
                        HStack(spacing: 3) {
                            Text("Rnk")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("\(searchRank)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gpBlue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.gpBlue.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Enhanced injury status with better styling
                if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "cross.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        
                        Text(String(injuryStatus.prefix(10)).capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Main gradient background
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: isCurrentPlayer ? Color.gpGreen.opacity(0.4) : Color.black.opacity(0.6), location: 0.0),
                        .init(color: positionColorFor(player.position ?? "").opacity(0.15), location: 0.5),
                        .init(color: isCurrentPlayer ? Color.gpGreen.opacity(0.2) : Color.black.opacity(0.8), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle overlay pattern
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.05),
                        Color.clear,
                        Color.white.opacity(0.02)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            isCurrentPlayer ? Color.gpGreen : Color.white.opacity(0.2),
                            isCurrentPlayer ? Color.gpGreen.opacity(0.6) : positionColorFor(player.position ?? "").opacity(0.3),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isCurrentPlayer ? 2 : 1
                )
        )
        .shadow(
            color: isCurrentPlayer ? Color.gpGreen.opacity(0.3) : Color.black.opacity(0.2), 
            radius: isCurrentPlayer ? 6 : 3, 
            x: 0, 
            y: isCurrentPlayer ? 3 : 2
        )
        .scaleEffect(isCurrentPlayer ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCurrentPlayer)
    }
    
    // Enhanced depth circle color function
    private func depthCircleColor(_ depth: Int) -> Color {
        switch depth {
        case 1: return Color.green
        case 2: return Color.orange  
        case 3: return Color.purple
        case 4: return Color.red
        default: return Color.gray
        }
    }
    
    private func getTeamPlayers() -> [String: [SleeperPlayer]] {
        guard let playerTeam = player.team else { return [:] }
        
        // Get all players from the same team
        let teamPlayers = playerDirectory.players.values.filter { p in
            p.team?.uppercased() == playerTeam.uppercased() && 
            p.status == "Active" &&
            p.position != nil
        }
        
        // Group by position
        let playersByPosition = Dictionary(grouping: teamPlayers) { p in
            p.position?.uppercased() ?? "UNKNOWN"
        }
        
        // Sort each position group by depth chart order
        var sortedByPosition: [String: [SleeperPlayer]] = [:]
        
        for (position, players) in playersByPosition {
            guard position != "UNKNOWN" else { continue }
            
            let sortedPlayers = players.sorted { p1, p2 in
                let order1 = p1.depthChartOrder ?? 99
                let order2 = p2.depthChartOrder ?? 99
                
                // If depth chart orders are the same, use searchRank as tiebreaker
                if order1 == order2 {
                    let rank1 = p1.searchRank ?? 999
                    let rank2 = p2.searchRank ?? 999
                    return rank1 < rank2
                }
                
                return order1 < order2
            }
            
            sortedByPosition[position] = sortedPlayers
        }
        
        return sortedByPosition
    }
    
    private func positionColorFor(_ position: String) -> Color {
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
    
    // MARK: -> Header Section
    
    private var playerHeaderSection: some View {
        VStack(spacing: 16) {
            // Large player image with better loading
            PlayerImageView(
                player: player,
                size: 120,
                team: team
            )
            
            // Player info
            VStack(spacing: 8) {
                Text(player.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    // Position badge
                    positionBadge
                    
                    // Team info
                    if let team = team {
                        HStack(spacing: 6) {
                            teamAssets.logoOrFallback(for: team.id)
                                .frame(width: 24, height: 24)
                            
                            Text(team.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Jersey number
                    if let number = player.number {
                        Text("#\(number)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            
            // Additional info
            HStack(spacing: 20) {
                if let age = player.age {
                    infoItem("Age", "\(age)")
                }
                if let yearsExp = player.yearsExp {
                    infoItem("Exp", "Y\(yearsExp)")
                }
                if let height = player.height {
                    infoItem("Height", height.formattedHeight)
                }
                if let weight = player.weight {
                    infoItem("Weight", "\(weight) lbs")
                }
            }
            .font(.caption)
        }
        .padding()
        .background(teamBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: -> Player Details
    
    private var playerDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let college = player.college {
                    detailRow("College", college)
                }
                
                if let height = player.height, let weight = player.weight {
                    detailRow("Size", "\(height.formattedHeight), \(weight) lbs")
                }
                
                if let yearsExp = player.yearsExp {
                    detailRow("Experience", "\(yearsExp) years")
                }
                
                if let searchRank = player.searchRank {
                    detailRow("Fantasy Rank", "#\(searchRank)")
                }
                
                if let depthChartPosition = player.depthChartPosition {
                    detailRow("Depth Chart", "Position \(depthChartPosition)")
                }
                
                if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                    HStack {
                        Text("Injury Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(injuryStatus.prefix(5)))
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Fantasy Analysis
    
    private var fantasyAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fantasy Analysis")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let searchRank = player.searchRank {
                    let tier = calculateFantasyTier(searchRank: searchRank, position: player.position ?? "")
                    
                    fantasyRow("Search Rank", "#\(searchRank)", tierColor(tier))
                    fantasyRow("Fantasy Tier", "Tier \(tier)", tierColor(tier))
                    
                    Text(getTierDescription(tier: tier, position: player.position ?? ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                // Position-specific analysis
                Text(getPositionAnalysis())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Helper Functions
    
    private func calculateFantasyTier(searchRank: Int, position: String) -> Int {
        switch position.uppercased() {
        case "QB":
            if searchRank <= 12 { return 1 }
            if searchRank <= 24 { return 2 }
            if searchRank <= 36 { return 3 }
            return 4
        case "RB":
            if searchRank <= 24 { return 1 }
            if searchRank <= 48 { return 2 }
            if searchRank <= 84 { return 3 }
            return 4
        case "WR":
            if searchRank <= 36 { return 1 }
            if searchRank <= 72 { return 2 }
            if searchRank <= 120 { return 3 }
            return 4
        case "TE":
            if searchRank <= 12 { return 1 }
            if searchRank <= 24 { return 2 }
            if searchRank <= 36 { return 3 }
            return 4
        default:
            return 4
        }
    }
    
    private func getTierDescription(tier: Int, position: String) -> String {
        switch (tier, position.uppercased()) {
        case (1, "QB"): return "Elite QB1 - Weekly starter"
        case (2, "QB"): return "Solid QB1 - Reliable starter"
        case (3, "QB"): return "Streaming QB - Matchup dependent"
        case (1, "RB"): return "Elite RB1/2 - Every week starter"
        case (2, "RB"): return "Solid RB2/3 - Good starter"
        case (3, "RB"): return "Flex RB - Spot starter"
        case (1, "WR"): return "Elite WR1/2 - Must start"
        case (2, "WR"): return "Solid WR2/3 - Good starter" 
        case (3, "WR"): return "Flex WR - Depth play"
        case (1, "TE"): return "Elite TE - Set and forget"
        case (2, "TE"): return "Solid TE - Weekly starter"
        case (3, "TE"): return "Streaming TE - Matchup play"
        default: return "Deep bench / waiver wire"
        }
    }
    
    private func getPositionAnalysis() -> String {
        let pos = player.position?.uppercased() ?? ""
        let rank = player.searchRank ?? 999
        
        switch pos {
        case "QB":
            return "QB\(rank <= 12 ? "1" : rank <= 24 ? "2" : "3+") - Target in rounds \(rank <= 12 ? "6-8" : rank <= 24 ? "9-12" : "13+")"
        case "RB":
            return "RB\(rank <= 12 ? "1" : rank <= 36 ? "2" : "3+") - Target in rounds \(rank <= 24 ? "1-3" : rank <= 48 ? "4-6" : "7+")"
        case "WR":
            return "WR\(rank <= 18 ? "1" : rank <= 48 ? "2" : "3+") - Target in rounds \(rank <= 36 ? "1-4" : rank <= 72 ? "5-8" : "9+")"
        case "TE":
            return "TE\(rank <= 6 ? "1" : rank <= 18 ? "2" : "3+") - Target in rounds \(rank <= 12 ? "4-6" : rank <= 24 ? "7-10" : "11+")"
        default:
            return "Draft in later rounds based on team needs"
        }
    }

    // MARK: -> Helper Views
    
    private var playerFallbackImage: some View {
        Circle()
            .fill(team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
            .overlay(
                Text(player.firstName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(team?.accentColor ?? .white)
            )
    }
    
    private var positionBadge: some View {
        Text(player.position ?? "")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var positionColor: Color {
        guard let position = player.position else { return .gray }
        
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
    
    private var teamBackgroundView: some View {
        Group {
            if let team = team {
                RoundedRectangle(cornerRadius: 16)
                    .fill(team.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(team.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            }
        }
    }
    
    private func infoItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    private func statsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    private func fantasyRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .purple
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }
}