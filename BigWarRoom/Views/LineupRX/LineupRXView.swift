//
//  LineupRXView.swift
//  BigWarRoom
//
//  💊 Lineup RX - AI-powered lineup optimization and waiver recommendations
//

import SwiftUI

struct LineupRXView: View {
    let matchup: UnifiedMatchup
    
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var optimizationResult: LineupOptimizerService.OptimizationResult?
    @State private var waiverRecommendations: [LineupOptimizerService.WaiverRecommendation] = []
    @State private var errorMessage: String?
    @State private var showingWeekPicker = false  // 🗓️ Week picker state
    @State private var currentWeek: Int = WeekSelectionManager.shared.selectedWeek  // 🔥 Track week locally
    
    // 🔥 Performance: Cache expensive lookups
    @State private var sleeperPlayerCache: [String: SleeperPlayer] = [:]
    @State private var matchupInfoCache: [String: MatchupInfo] = [:]
    @State private var groupedWaivers: [WaiverGroup] = []
    @State private var changeInfoCache: [String: (isChanged: Bool, improvement: Double?)] = [:]
    @State private var gameTimeCache: [String: String] = [:]  // team -> formatted game time
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Image("BG7")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    LazyVStack(spacing: 20, pinnedViews: []) {
                        // Header
                        headerSection
                        
                        if isLoading {
                            loadingView
                        } else if let error = errorMessage {
                            errorView(error)
                        } else {
                            // Content sections
                            if let result = optimizationResult {
                                currentLineupAnalysisSection(result)
                                    .id("analysis")
                                
                                if !result.changes.isEmpty {
                                    recommendedChangesSection(result)
                                        .id("changes")
                                }
                                
                                byeWeekAlertsSection
                                    .id("bye")
                                
                                if !waiverRecommendations.isEmpty {
                                    waiverWireSection
                                        .id("waiver")
                                }
                                
                                optimalLineupSummarySection(result)
                                    .id("optimal")
                            }
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.visible)
            }
            .navigationTitle("Lineup RX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.gpBlue)
                    }
                }
            }
            .onAppear {
                currentWeek = WeekSelectionManager.shared.selectedWeek
                Task {
                    await loadData()
                }
            }
        }
        .fullScreenCover(isPresented: $showingWeekPicker) {
            WeekPickerView(
                weekManager: WeekSelectionManager.shared,
                isPresented: $showingWeekPicker
            )
        }
        .onChange(of: showingWeekPicker) { oldValue, newValue in
            // 🔥 When week picker closes, check if week changed
            if !newValue && currentWeek != WeekSelectionManager.shared.selectedWeek {
                currentWeek = WeekSelectionManager.shared.selectedWeek
                Task {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // League info
            HStack {
                Text(matchup.league.league.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Week selector button - matches Mission Control style
                Button(action: {
                    showingWeekPicker = true
                }) {
                    HStack(spacing: 6) {
                        Text("WEEK \(currentWeek)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gpBlue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpBlue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gpBlue.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gpBlue.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
            }
            
            // Manager info
            if let myTeam = matchup.myTeam {
                HStack {
                    if let avatarURL = myTeam.avatarURL {
                        AsyncImage(url: avatarURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Circle()
                                    .fill(Color.gpBlue.opacity(0.3))
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(myTeam.ownerName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let record = myTeam.record?.displayString {
                            Text("Record: \(record)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gpBlue))
                .scaleEffect(1.5)
            
            Text("Analyzing your lineup...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("Fetching projections and optimizing...")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.gpRedPink)
            
            Text("Error")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpRedPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Current Lineup Analysis Section
    
    private func currentLineupAnalysisSection(_ result: LineupOptimizerService.OptimizationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "chart.bar.fill", title: "Current Lineup Analysis", color: .gpBlue)
            
            // Show congratulatory badge if lineup is already optimized
            if result.improvement <= 0.1 {
                optimizedLineupBadge
            }
            
            HStack(spacing: 20) {
                statCard(
                    title: "Current Score",
                    value: String(format: "%.1f", result.currentPoints),
                    color: .white
                )
                
                statCard(
                    title: "Optimal Score",
                    value: String(format: "%.1f", result.projectedPoints),
                    color: .gpGreen
                )
                
                statCard(
                    title: "Improvement",
                    value: String(format: "+%.1f", result.improvement),
                    color: result.improvement > 0 ? .gpGreen : .gray
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var optimizedLineupBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.gpGreen, .gpGreen.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("🎯 Lineup Optimized!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("Your lineup is already at maximum projected points")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gpGreen.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gpGreen.opacity(0.4), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Recommended Changes Section
    
    private func recommendedChangesSection(_ result: LineupOptimizerService.OptimizationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "arrow.triangle.2.circlepath", title: "Recommended Lineup Changes", color: .gpGreen)
            
            ForEach(result.changes.indices, id: \.self) { index in
                let change = result.changes[index]
                changeCard(change)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Bye Week Alerts Section
    
    private var byeWeekAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "exclamationmark.triangle.fill", title: "Bye Week & Injury Alerts", color: .orange)
            
            // TODO: Implement bye week detection
            Text("No bye week or injury alerts this week")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Waiver Wire Section
    
    private var waiverWireSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "person.badge.plus.fill", title: "Waiver Wire Targets", color: .purple)
            
            // Group recommendations by drop candidate
            ForEach(groupedWaivers, id: \.dropPlayer.id) { group in
                groupedWaiverCard(group)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // Group waiver recommendations by drop candidate
    private func groupWaiverRecommendations() {
        var groups: [String: WaiverGroup] = [:]
        
        for rec in waiverRecommendations {
            let dropID = rec.playerToDrop.id
            
            if var existing = groups[dropID] {
                existing.addOptions.append(WaiverAddOption(
                    playerID: rec.playerToAdd.playerID,
                    name: rec.playerToAdd.name,
                    position: rec.playerToAdd.position,
                    team: rec.playerToAdd.team,
                    projectedPoints: rec.playerToAdd.projectedPoints,
                    reason: rec.reason
                ))
                groups[dropID] = existing
            } else {
                groups[dropID] = WaiverGroup(
                    dropPlayer: rec.playerToDrop,
                    dropProjectedPoints: rec.projectedPointsDrop,
                    addOptions: [WaiverAddOption(
                        playerID: rec.playerToAdd.playerID,
                        name: rec.playerToAdd.name,
                        position: rec.playerToAdd.position,
                        team: rec.playerToAdd.team,
                        projectedPoints: rec.playerToAdd.projectedPoints,
                        reason: rec.reason
                    )]
                )
            }
        }
        
        groupedWaivers = Array(groups.values).sorted { $0.dropPlayer.fullName < $1.dropPlayer.fullName }
    }
    
    private struct WaiverGroup {
        let dropPlayer: FantasyPlayer
        let dropProjectedPoints: Double
        var addOptions: [WaiverAddOption]
    }
    
    private struct WaiverAddOption {
        let playerID: String
        let name: String
        let position: String
        let team: String
        let projectedPoints: Double
        let reason: String
    }
    
    // MARK: - Optimal Lineup Summary Section
    
    private func optimalLineupSummarySection(_ result: LineupOptimizerService.OptimizationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with total
            HStack {
                sectionHeader(icon: "star.fill", title: "Optimal Lineup", color: .gpGreen)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", result.projectedPoints))
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.gpGreen)
                    
                    Text("TOTAL PTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            
            // Define proper position order
            let positionOrder = ["QB", "RB", "WR", "TE", "FLEX", "SUPERFLEX", "D/ST", "K"]
            
            ForEach(positionOrder, id: \.self) { position in
                if let players = result.optimalLineup[position], !players.isEmpty {
                    positionGroup(
                        position: position,
                        players: players,
                        projections: result.playerProjections,
                        changes: result.changes
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private func changeCard(_ change: LineupOptimizerService.LineupChange) -> some View {
        VStack(spacing: 12) {
            // Position header
            HStack {
                Text(change.position)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.gpGreen)
                    Text(change.reason)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gpGreen)
                }
            }
            
            // BENCH player
            playerComparisonRow(
                player: change.playerOut,
                label: "BENCH",
                labelColor: .gpRedPink,
                projectedPoints: change.projectedPointsOut,
                iconName: "arrow.down"
            )
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // PLAY player
            playerComparisonRow(
                player: change.playerIn,
                label: "PLAY",
                labelColor: .gpGreen,
                projectedPoints: change.projectedPointsIn,
                iconName: "arrow.up"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func groupedWaiverCard(_ group: WaiverGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // DROP player (shown once)
            playerComparisonRow(
                player: group.dropPlayer,
                label: "DROP",
                labelColor: .gpRedPink,
                projectedPoints: group.dropProjectedPoints,
                iconName: nil
            )
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Multiple ADD options
            ForEach(group.addOptions.indices, id: \.self) { index in
                let option = group.addOptions[index]
                
                VStack(alignment: .leading, spacing: 8) {
                    waiverPlayerRow(
                        playerID: option.playerID,
                        name: option.name,
                        position: option.position,
                        team: option.team,
                        label: "ADD",
                        labelColor: .gpGreen,
                        projectedPoints: option.projectedPoints
                    )
                    
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.purple)
                        
                        Text(option.reason)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                if index < group.addOptions.count - 1 {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                        .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private func positionGroup(
        position: String,
        players: [FantasyPlayer],
        projections: [String: Double],
        changes: [LineupOptimizerService.LineupChange]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Position header
            Text(position)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gpGreen)
                .padding(.bottom, 4)
            
            // Players in this position - 🔥 Use LazyVStack for performance
            LazyVStack(spacing: 12) {
                ForEach(players, id: \.id) { player in
                    OptimalLineupPlayerRow(
                        player: player,
                        position: position,
                        projections: projections,
                        changes: changes,
                        sleeperPlayerCache: sleeperPlayerCache,
                        changeInfoCache: changeInfoCache
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // Helper to determine if a player is part of a lineup change
    private func getChangeInfo(
        for player: FantasyPlayer,
        in position: String,
        changes: [LineupOptimizerService.LineupChange]
    ) -> (isChanged: Bool, improvement: Double?) {
        // 🔥 Create cache key
        let cacheKey = "\(player.id)_\(position)"
        
        // Only read from cache during view rendering
        if let cached = changeInfoCache[cacheKey] {
            return cached
        }
        
        // If not in cache, calculate without storing
        if let change = changes.first(where: { $0.playerIn.id == player.id && $0.position == position }) {
            return (true, change.improvement)
        }
        return (false, nil)
    }
    
    // Visual indicator for lineup changes
    private func changeIndicator(for changeInfo: (isChanged: Bool, improvement: Double?)) -> some View {
        Group {
            if changeInfo.isChanged {
                // Player is being moved from bench
                if let improvement = changeInfo.improvement, improvement > 5.0 {
                    // Big improvement - gold star
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    // Regular change - blue swap
                    ZStack {
                        Circle()
                            .fill(Color.gpBlue)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            } else {
                // Already optimized - green checkmark
                ZStack {
                    Circle()
                        .fill(Color.gpGreen)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Enhanced Player Row Components
    
    /// Rich player comparison row with headshot, team logo, opponent, OPRK, and game time
    private func playerComparisonRow(
        player: FantasyPlayer,
        label: String,
        labelColor: Color,
        projectedPoints: Double,
        iconName: String?
    ) -> some View {
        HStack(spacing: 12) {
            // Icon (optional)
            if let iconName = iconName {
                Image(systemName: iconName)
                    .foregroundColor(labelColor)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 20)
            }
            
            // Player headshot
            if let sleeperPlayer = getSleeperPlayer(for: player) {
                AsyncImage(url: sleeperPlayer.headshotURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(labelColor.opacity(0.5), lineWidth: 2)
                )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(label):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(labelColor)
                    
                    Text(player.fullName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    // Position and team logo
                    HStack(spacing: 4) {
                        Text(player.position)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        if let team = player.team {
                            teamLogoView(team: team, size: 24)
                        }
                    }
                    
                    // Opponent matchup with OPRK
                    if let matchupInfo = getMatchupInfo(for: player) {
                        Text("•")
                            .foregroundColor(.gray.opacity(0.5))
                        
                        HStack(spacing: 4) {
                            Text(matchupInfo.isHome ? "vs" : "@")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                            
                            teamLogoView(team: matchupInfo.opponentTeam, size: 24)
                            
                            if let oprk = matchupInfo.oprk {
                                oprkBadge(rank: oprk)
                            }
                        }
                    }
                }
                
                // Game time
                if let gameTime = getGameTime(for: player) {
                    Text(gameTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gpBlue.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Projected points
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", projectedPoints))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(labelColor)
                
                Text("pts")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    /// Waiver player row (for ADD players who aren't on roster yet)
    private func waiverPlayerRow(
        playerID: String,
        name: String,
        position: String,
        team: String,
        label: String,
        labelColor: Color,
        projectedPoints: Double
    ) -> some View {
        HStack(spacing: 12) {
            // Player headshot from Sleeper
            if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: playerID) {
                AsyncImage(url: sleeperPlayer.headshotURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(labelColor.opacity(0.5), lineWidth: 2)
                )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(label):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(labelColor)
                    
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    // Position and team logo
                    HStack(spacing: 4) {
                        Text(position)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        teamLogoView(team: team, size: 24)
                    }
                    
                    // Opponent matchup with OPRK
                    if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: playerID),
                       let matchupInfo = getMatchupInfoForSleeperPlayer(sleeperPlayer) {
                        Text("•")
                            .foregroundColor(.gray.opacity(0.5))
                        
                        HStack(spacing: 4) {
                            Text(matchupInfo.isHome ? "vs" : "@")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                            
                            teamLogoView(team: matchupInfo.opponentTeam, size: 24)
                            
                            if let oprk = matchupInfo.oprk {
                                oprkBadge(rank: oprk)
                            }
                        }
                    }
                }
                
                // Game time
                if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: playerID),
                   let gameTime = getGameTimeForSleeperPlayer(sleeperPlayer) {
                    Text(gameTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gpBlue.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Projected points
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", projectedPoints))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(labelColor)
                
                Text("pts")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Helper Components
    
    private func teamLogoView(team: String, size: CGFloat) -> some View {
        AsyncImage(url: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }
    
    private func oprkBadge(rank: Int) -> some View {
        let color: Color = {
            switch rank {
            case 1...10: return .gpGreen
            case 11...20: return .orange
            default: return .gpRedPink
            }
        }()
        
        return Text("#\(rank)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
    }
    
    // MARK: - Data Helpers
    
    private func getSleeperPlayer(for player: FantasyPlayer) -> SleeperPlayer? {
        guard let sleeperID = player.sleeperID else { return nil }
        
        // 🔥 Only read from cache during view rendering
        if let cached = sleeperPlayerCache[sleeperID] {
            return cached
        }
        
        // If not in cache, return nil (cache should be pre-populated)
        return nil
    }
    
    private struct MatchupInfo {
        let opponent: String
        let opponentTeam: String
        let isHome: Bool
        let oprk: Int?
    }
    
    private func getMatchupInfo(for player: FantasyPlayer) -> MatchupInfo? {
        guard let team = player.team else { return nil }
        
        // 🔥 Create cache key
        let cacheKey = "\(team)_\(player.position)"
        
        // Only read from cache during view rendering
        return matchupInfoCache[cacheKey]
    }
    
    private func getMatchupInfoForSleeperPlayer(_ player: SleeperPlayer) -> MatchupInfo? {
        guard let team = player.team else { return nil }
        
        // 🔥 Create cache key
        let position = player.position ?? "UNKNOWN"
        let cacheKey = "\(team)_\(position)"
        
        // Only read from cache during view rendering
        return matchupInfoCache[cacheKey]
    }
    
    private func getGameTime(for player: FantasyPlayer) -> String? {
        guard let team = player.team else { return nil }
        // 🔥 Use cache
        return gameTimeCache[team]
    }
    
    private func getGameTimeForSleeperPlayer(_ player: SleeperPlayer) -> String? {
        guard let team = player.team else { return nil }
        // 🔥 Use cache
        return gameTimeCache[team]
    }
    
    // MARK: - Cache Population
    
    /// Pre-populate all caches after data loads to avoid state modification during view rendering
    private func populateCaches(result: LineupOptimizerService.OptimizationResult) {
        // Populate sleeper player cache
        if let myTeam = matchup.myTeam {
            for player in myTeam.roster {
                if let sleeperID = player.sleeperID,
                   let sleeperPlayer = PlayerDirectoryStore.shared.player(for: sleeperID) {
                    sleeperPlayerCache[sleeperID] = sleeperPlayer
                }
            }
        }
        
        // Populate matchup info cache and game time cache for all players
        if let myTeam = matchup.myTeam {
            for player in myTeam.roster {
                guard let team = player.team else { continue }
                let cacheKey = "\(team)_\(player.position)"
                
                if matchupInfoCache[cacheKey] == nil {
                    if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
                        let isHome = gameInfo.homeTeam == team
                        let opponent = isHome ? "vs \(gameInfo.awayTeam)" : "@ \(gameInfo.homeTeam)"
                        let opponentTeam = isHome ? gameInfo.awayTeam : gameInfo.homeTeam
                        let oprk = OPRKService.shared.getOPRK(forTeam: opponentTeam, position: player.position)
                        
                        matchupInfoCache[cacheKey] = MatchupInfo(
                            opponent: opponent,
                            opponentTeam: opponentTeam,
                            isHome: isHome,
                            oprk: oprk
                        )
                        
                        // 🔥 Also cache game time for this team
                        if gameTimeCache[team] == nil {
                            gameTimeCache[team] = gameInfo.formattedGameTime
                        }
                    }
                }
            }
        }
        
        // Populate change info cache
        for change in result.changes {
            let cacheKey = "\(change.playerIn.id)_\(change.position)"
            changeInfoCache[cacheKey] = (true, change.improvement)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        // 🔥 Clear caches when reloading
        sleeperPlayerCache.removeAll()
        matchupInfoCache.removeAll()
        changeInfoCache.removeAll()
        gameTimeCache.removeAll()
        
        do {
            let week = WeekSelectionManager.shared.selectedWeek
            let year = SeasonYearManager.shared.selectedYear
            
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: Starting analysis for week \(week) \(year)")
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: League: \(matchup.league.league.name)")
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: My Team: \(matchup.myTeam?.ownerName ?? "Unknown")")
            
            // Validate we have team data
            guard let myTeam = matchup.myTeam else {
                DebugPrint(mode: .lineupRX, "❌ LINEUP RX: No team data available")
                throw LineupRXError.noTeamData
            }
            
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: Roster size: \(myTeam.roster.count) players")
            
            // Determine scoring format (default to PPR for now)
            let scoringFormat = "ppr"  // TODO: Detect from league settings
            
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: Calling optimizeLineup...")
            
            // Optimize lineup
            let result = try await LineupOptimizerService.shared.optimizeLineup(
                for: matchup,
                week: week,
                year: year,
                scoringFormat: scoringFormat
            )
            
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: ✅ Optimization complete. \(result.changes.count) changes recommended")
            
            optimizationResult = result
            
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: Calling getWaiverRecommendations...")
            
            // Get waiver recommendations
            let waiver = try await LineupOptimizerService.shared.getWaiverRecommendations(
                for: matchup,
                week: week,
                year: year,
                limit: 5,
                scoringFormat: scoringFormat
            )
            
            DebugPrint(mode: .lineupRX, "💊 LINEUP RX: ✅ Waiver analysis complete. \(waiver.count) recommendations")
            
            waiverRecommendations = waiver
            
            // 🔥 Group waivers once after loading
            groupWaiverRecommendations()
            
            // 🔥 Pre-populate caches to avoid state modification during view rendering
            populateCaches(result: result)
            
            isLoading = false
        } catch {
            DebugPrint(mode: .lineupRX, "❌ LINEUP RX: Error - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    enum LineupRXError: Error, LocalizedError {
        case noTeamData
        
        var errorDescription: String? {
            switch self {
            case .noTeamData:
                return "No team data available for this matchup"
            }
        }
    }
}

// MARK: - Optimal Lineup Player Row
/// Separate view to prevent re-evaluation of computed properties on every scroll
private struct OptimalLineupPlayerRow: View {
    let player: FantasyPlayer
    let position: String
    let projections: [String: Double]
    let changes: [LineupOptimizerService.LineupChange]
    let sleeperPlayerCache: [String: SleeperPlayer]
    let changeInfoCache: [String: (isChanged: Bool, improvement: Double?)]
    
    // 🔥 Compute these ONCE when the view is created, not on every scroll
    private var changeInfo: (isChanged: Bool, improvement: Double?) {
        let cacheKey = "\(player.id)_\(position)"
        if let cached = changeInfoCache[cacheKey] {
            return cached
        }
        if let change = changes.first(where: { $0.playerIn.id == player.id && $0.position == position }) {
            return (true, change.improvement)
        }
        return (false, nil)
    }
    
    private var sleeperPlayer: SleeperPlayer? {
        guard let sleeperID = player.sleeperID else { return nil }
        return sleeperPlayerCache[sleeperID]
    }
    
    private var depthPosition: Int? {
        sleeperPlayer?.depthChartPosition
    }
    
    private var projectedPts: Double {
        player.sleeperID.flatMap { projections[$0] } ?? 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Change indicator
            changeIndicatorView
            
            // Player headshot
            playerHeadshotView
            
            // Player info
            playerInfoView
            
            Spacer()
            
            // Projected points
            projectedPointsView
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(changeInfo.isChanged ? Color.gpBlue.opacity(0.15) : Color.black.opacity(0.4))
        )
    }
    
    private var changeIndicatorView: some View {
        Group {
            if changeInfo.isChanged {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundColor(.gpBlue)
                    .font(.system(size: 16))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.gpGreen)
                    .font(.system(size: 16))
            }
        }
    }
    
    private var playerHeadshotView: some View {
        Group {
            if let sleeperPlayer = sleeperPlayer {
                AsyncImage(url: sleeperPlayer.headshotURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    private var playerInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(player.fullName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 6) {
                // Position badge with NFL depth chart position
                if let depth = depthPosition {
                    Text("\(player.position)\(depth)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gpGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gpGreen.opacity(0.2))
                        )
                } else {
                    Text(player.position)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gpGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gpGreen.opacity(0.2))
                        )
                }
                
                // Team logo
                if let team = player.team {
                    TeamLogoView(teamCode: team, size: 20)
                }
            }
        }
    }
    
    private var projectedPointsView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.1f", projectedPts))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gpGreen)
            
            Text("pts")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}
