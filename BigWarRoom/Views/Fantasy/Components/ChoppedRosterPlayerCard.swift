//
//  ChoppedRosterPlayerCard.swift
//  BigWarRoom
//
//  🏈 CHOPPED ROSTER PLAYER CARD 🏈
//  Enhanced player card using All Live Players styling with chopped data
//

import SwiftUI

/// **ChoppedRosterPlayerCard**
/// 
/// Player card using All Live Players visual styling with chopped roster data
struct ChoppedRosterPlayerCard: View {
    @StateObject private var viewModel: ChoppedPlayerCardViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    let compact: Bool
    
    @State private var showingScoreBreakdown = false
    
    init(player: FantasyPlayer, isStarter: Bool, parentViewModel: ChoppedTeamRosterViewModel, onPlayerTap: @escaping (SleeperPlayer) -> Void, compact: Bool = false) {
        self._viewModel = StateObject(wrappedValue: ChoppedPlayerCardViewModel(
            player: player,
            isStarter: isStarter,
            parentViewModel: parentViewModel
        ))
        self.onPlayerTap = onPlayerTap
        self.compact = compact
    }
    
    // MARK: - Card Dimensions
    private var cardHeight: CGFloat {
        compact ? 90 : 140 // Increased height: compact 70→90, regular 110→140
    }
    
    var body: some View {
        Button(action: {
            if let sleeperPlayer = viewModel.sleeperPlayer {
                onPlayerTap(sleeperPlayer)
            }
        }) {
            ZStack(alignment: .leading) {
                // Build the card content using All Live Players layout
                HStack(spacing: 0) {
                    // Empty space for where image will be overlaid
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 65) // Space for image
                    
                    // Center matchup section
                    VStack {
                        Spacer()
                        MatchupTeamFinalView(player: viewModel.player)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .offset(x: 37)
                    .scaleEffect(1.1)
                    
                    // Player info - right side
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Spacer()
                            
                            // Player name - MUCH LARGER
                            Text(viewModel.player.fullName)
                                .font(.system(size: compact ? 24 : 24, weight: .bold)) // Increased from 14/18 to 18/24
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        
                        HStack(spacing: 6) {
                            Spacer()
                            
                            // Position badge
                            Text(viewModel.badgeText)
                                .font(.system(size: compact ? 10 : 8, weight: .bold))
                                .padding(.horizontal, compact ? 4 : 6)
                                .padding(.vertical, compact ? 4 : 3)
                                .background(viewModel.badgeColor.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        // Score info - UPDATED: Make score tappable only if has points
                        HStack(spacing: 8) {
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 8) {
                                    if let points = viewModel.actualPoints, points > 0 {
                                        // UPDATED: Make score tappable
                                        Button(action: {
                                            showingScoreBreakdown = true
                                        }) {
                                            Text(String(format: "%.1f", points))
                                                .font(.callout)
                                                .fontWeight(.bold)
                                                .foregroundColor(scoreColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                        .padding(-2)
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        // REVERT: Show 0.0 for no points (original logic)
                                        Text("0.0")
                                            .font(.callout)
                                            .fontWeight(.bold)
                                            .foregroundColor(.gray)
                                    }
                                    
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
                    // All Live Players style background with score bar
                    allLivePlayersBackground
                )
                
                // Stats section at bottom (only if has points)
                if let points = viewModel.actualPoints, points > 0,
                   let statLine = viewModel.statBreakdown {
                    VStack {
                        Spacer()
                        HStack {
                            Text(statLine)
                                .font(.system(size: compact ? 8 : 9, weight: .bold))
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
                
                // Player image overlay
                HStack {
                    ZStack {
                        // Team logo behind player
                        if let team = viewModel.player.team {
                            TeamAssetManager.shared.logoOrFallback(for: team)
                                .frame(width: compact ? 140 : 140, height: compact ? 140 : 140)
                                .opacity(0.25)
                                .offset(x: 10, y: -5)
                                .zIndex(0)
                        }
                        
                        // Player image in front
                        playerImageView
                            .zIndex(1)
                            .offset(x: -30) // Changed from x: -50 to x: -30 (moved 20 points to the right)
                    }
                    .frame(height: compact ? 60 : 80)
                    .frame(maxWidth: compact ? 120 : 180)
                    .offset(x: -10)
                    Spacer()
                }
            }
            .frame(height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            // All Live Players style border
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    viewModel.player.isLive ? 
                        LinearGradient(colors: [.blue, .gpGreen], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.gpYellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: viewModel.player.isLive ? 3 : 2
                )
                .opacity(viewModel.player.isLive ? 0.8 : 0.6)
        )
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
        guard let sleeperPlayer = viewModel.sleeperPlayer else {
            return nil
        }
        
        let rosterWeek = viewModel.getCurrentWeek()
        
        // 🔥 UPDATED: Use smart filtered scoring settings 
        let leagueScoring = viewModel.parentViewModel.getLeagueScoringSettings()
        
        // Create league context for chopped league
        let leagueContext = LeagueContext.chopped(scoringSettings: leagueScoring ?? [:])
        
        // Use the chopped view model as local stats provider  
        let localStatsProvider = viewModel.parentViewModel.statsProvider
        
        // 🔥 NEW: Create breakdown with ESPN's authoritative total but show stats for transparency
        return ScoreBreakdownFactory.createTransparentBreakdown(
            for: viewModel.player,
            week: rosterWeek,
            authoritativeTotal: viewModel.actualPoints ?? 0.0, // ESPN's appliedTotal
            localStatsProvider: localStatsProvider,
            leagueContext: leagueContext
        )
    }
    
    /// Creates empty breakdown for players with no stats
    private func createEmptyBreakdown() -> PlayerScoreBreakdown {
        let rosterWeek = viewModel.getCurrentWeek()
        return PlayerScoreBreakdown(
            player: viewModel.player,
            week: rosterWeek,
            items: [], // No stats to show
            totalScore: viewModel.actualPoints ?? 0.0, // Use ESPN's authoritative total
            isChoppedLeague: true // Chopped league
        )
    }
    
    // MARK: - All Live Players Style Background
    
    private var allLivePlayersBackground: some View {
        ZStack {
            // Base gradient background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.9),
                            viewModel.teamPrimaryColor.opacity(0.3),
                            Color.black.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Score bar (left side)
            HStack {
                Rectangle()
                    .fill(scoreBarGradient)
                    .frame(width: scoreBarWidth)
                    .opacity(0.4)
                
                Spacer()
            }
            
            // Team accent overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            viewModel.teamPrimaryColor.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Player Image View
    
    private var playerImageView: some View {
        Group {
            if let sleeperPlayer = viewModel.sleeperPlayer,
               let imageURL = sleeperPlayer.headshotURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: compact ? 100 : 80, height: compact ? 100 : 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    playerImageFallback
                }
            } else {
                playerImageFallback
            }
        }
    }
    
    private var playerImageFallback: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(viewModel.teamPrimaryColor.opacity(0.6))
            .frame(width: compact ? 80 : 80, height: compact ? 80 : 80)
            .overlay(
                Text(viewModel.player.position)
                    .font(.system(size: compact ? 12 : 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - Computed Properties
    
    private var scoreColor: Color {
        if let points = viewModel.actualPoints {
            if points >= 20 { return .gpGreen }
            else if points >= 12 { return .blue }
            else if points >= 8 { return .orange }
            else { return .gpRedPink }
        }
        return .gray
    }
    
    private var scoreBarWidth: CGFloat {
        guard let points = viewModel.actualPoints else { return 8 }
        let maxPoints: Double = 60.0
        let percentage = min(points / maxPoints, 1.0)
        let minWidth: CGFloat = 8
        let maxWidth: CGFloat = 120
        return minWidth + (CGFloat(percentage) * (maxWidth - minWidth))
    }
    
    private var scoreBarGradient: LinearGradient {
        guard let points = viewModel.actualPoints else {
            return LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
        
        if points >= 20 {
            return LinearGradient(colors: [.gpGreen.opacity(0.8), .gpGreen.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        } else if points >= 12 {
            return LinearGradient(colors: [.blue.opacity(0.8), .blue.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        } else if points >= 8 {
            return LinearGradient(colors: [.orange.opacity(0.8), .orange.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red.opacity(0.6), .red.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

#Preview {
    // Cannot preview without proper ViewModel setup
    Text("ChoppedRosterPlayerCard Preview")
        .foregroundColor(.white)
        .background(Color.black)
}