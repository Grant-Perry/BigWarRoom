//
//  ChoppedRosterPlayerCard.swift
//  BigWarRoom
//
//  🔥 PHASE 2 SIMPLIFIED MIGRATION: Use existing UnifiedPlayerCardBackground
//

import SwiftUI

/// **ChoppedRosterPlayerCard - SIMPLIFIED MIGRATION**
/// 
/// **Strategy:** Keep working functionality, eliminate background duplication
/// **Before:** 400+ lines with custom All Live Players styling
/// **After:** Use UnifiedPlayerCardBackground + existing logic
struct ChoppedRosterPlayerCard: View {
    @State private var viewModel: ChoppedPlayerCardViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    let compact: Bool
    
    @State private var showingScoreBreakdown = false
    
    init(player: FantasyPlayer, isStarter: Bool, parentViewModel: ChoppedTeamRosterViewModel, onPlayerTap: @escaping (SleeperPlayer) -> Void, compact: Bool = false) {
        self.viewModel = ChoppedPlayerCardViewModel(
            player: player,
            isStarter: isStarter,
            parentViewModel: parentViewModel
        )
        self.onPlayerTap = onPlayerTap
        self.compact = compact
    }
    
    private var cardHeight: CGFloat {
        compact ? 90 : 140
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 🔥 UNIFIED: Use UnifiedPlayerCardBackground instead of custom background logic
            if let livePlayerEntry = createLivePlayerEntry() {
                UnifiedPlayerCardBackground(
                    configuration: .scoreBar(
                        playerEntry: livePlayerEntry,
                        scoreBarWidth: calculateScoreBarWidth(),
                        team: NFLTeam.team(for: viewModel.player.team ?? "")
                    )
                )
            } else {
                UnifiedPlayerCardBackground(
                    configuration: .simple(
                        team: NFLTeam.team(for: viewModel.player.team ?? ""),
                        cornerRadius: 12
                    )
                )
            }
            
            // 🔥 SIMPLIFIED: Keep existing content layout but cleaned up
            buildCardContent()
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if let sleeperPlayer = viewModel.sleeperPlayer {
                onPlayerTap(sleeperPlayer)
            }
        }
        .sheet(isPresented: $showingScoreBreakdown) {
            buildScoreBreakdownSheet()
        }
    }
    
    // MARK: - Content Builder
    
    @ViewBuilder
    private func buildCardContent() -> some View {
        HStack(spacing: 0) {
            // Player info section
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Spacer()
                    
                    Text(viewModel.player.fullName)
                        .font(.system(size: compact ? 24 : 24, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                HStack(spacing: 6) {
                    Spacer()
                    
                    Text(viewModel.badgeText)
                        .font(.system(size: compact ? 10 : 8, weight: .bold))
                        .padding(.horizontal, compact ? 4 : 6)
                        .padding(.vertical, compact ? 4 : 3)
                        .background(viewModel.badgeColor.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Score section
                buildScoreSection()
            }
            .frame(maxHeight: .infinity, alignment: .top)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        
        // Player image overlay  
        HStack {
            buildPlayerImage()
            Spacer()
        }
        
        // Stats section at bottom
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
    }
    
    @ViewBuilder
    private func buildScoreSection() -> some View {
        HStack(spacing: 8) {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    if let points = viewModel.actualPoints, points > 0 {
                        Button(action: {
                            showingScoreBreakdown = true
                        }) {
                            Text(String(format: "%.1f", points))
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(scoreColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
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
    
    @ViewBuilder
    private func buildPlayerImage() -> some View {
        ZStack {
            // Team logo behind player
            if let team = viewModel.player.team {
                TeamAssetManager.shared.logoOrFallback(for: team)
                    .frame(width: 140, height: 140)
                    .opacity(0.25)
                    .offset(x: 10, y: -5)
                    .zIndex(0)
            }
            
            // Player image in front
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
                        buildPlayerImageFallback()
                    }
                } else {
                    buildPlayerImageFallback()
                }
            }
            .scaleEffect(0.9)
            .zIndex(1)
            .offset(x: -20)
        }
        .frame(height: compact ? 60 : 80)
        .frame(maxWidth: compact ? 120 : 180)
        .offset(x: -10)
    }
    
    @ViewBuilder
    private func buildPlayerImageFallback() -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(viewModel.teamPrimaryColor.opacity(0.6))
            .frame(width: compact ? 80 : 80, height: compact ? 80 : 80)
            .overlay(
                Text(viewModel.player.position)
                    .font(.system(size: compact ? 12 : 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    @ViewBuilder
    private func buildScoreBreakdownSheet() -> some View {
        if let breakdown = createScoreBreakdown() {
            ScoreBreakdownView(breakdown: breakdown)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(16)
        } else {
            ScoreBreakdownView(breakdown: createEmptyBreakdown())
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(16)
        }
    }
    
    // MARK: - Helper Methods
    
    private var scoreColor: Color {
        if let points = viewModel.actualPoints {
            if points >= 20 { return .gpGreen }
            else if points >= 12 { return .blue }
            else if points >= 8 { return .orange }
            else { return .gpRedPink }
        }
        return .gray
    }
    
    private func createLivePlayerEntry() -> (any PlayerEntry)? {
        return ChoppedLivePlayerEntryAdapter(player: viewModel.player)
    }
    
    private func calculateScoreBarWidth() -> Double {
        let maxPoints: Double = 40.0
        let currentPoints = viewModel.actualPoints ?? 0.0
        return min(currentPoints / maxPoints, 1.0)
    }
    
    // Score breakdown methods (keeping existing implementation)
    private func createScoreBreakdown() -> PlayerScoreBreakdown? {
        guard let sleeperPlayer = viewModel.sleeperPlayer else { return nil }
        
        let rosterWeek = viewModel.getCurrentWeek()
        let authoritativeScore = viewModel.actualPoints ?? 0.0
        
        let leagueContext = LeagueContext(
            leagueID: "chopped",
            source: .sleeper,
            isChopped: true,
            customScoringSettings: viewModel.parentViewModel.getLeagueScoringSettings()
        )
        
        let localStatsProvider = viewModel.parentViewModel.statsProvider
        
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: viewModel.player,
            week: rosterWeek,
            localStatsProvider: localStatsProvider,
            leagueContext: leagueContext
        ).withLeagueName("Chopped League")
        
        return PlayerScoreBreakdown(
            player: breakdown.player,
            week: breakdown.week,
            items: breakdown.items,
            totalScore: authoritativeScore,
            isChoppedLeague: breakdown.isChoppedLeague,
            hasRealScoringData: true,
            leagueContext: breakdown.leagueContext,
            leagueName: breakdown.leagueName
        )
    }
    
    private func createEmptyBreakdown() -> PlayerScoreBreakdown {
        let rosterWeek = viewModel.getCurrentWeek()
        let authoritativeScore = viewModel.actualPoints ?? 0.0
        
        return PlayerScoreBreakdown(
            player: viewModel.player,
            week: rosterWeek,
            items: [],
            totalScore: authoritativeScore,
            isChoppedLeague: true,
            hasRealScoringData: true,
            leagueContext: LeagueContext(
                leagueID: "chopped",
                source: .sleeper,
                isChopped: true,
                customScoringSettings: nil
            ),
            leagueName: "Chopped League"
        )
    }
}

// MARK: - Adapter for PlayerEntry Protocol

private struct ChoppedLivePlayerEntryAdapter: PlayerEntry {
    let player: FantasyPlayer
    
    var currentScore: Double { player.currentPoints ?? 0.0 }
    var scoreBarWidth: Double {
        let maxPoints: Double = 40.0
        return min(currentScore / maxPoints, 1.0)
    }
}