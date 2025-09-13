//
//  MatchupTeamFinalView.swift
//  BigWarRoom
//
//  🏈 DRY COMPONENT: Reusable NFL game matchup display with enhanced FINAL game styling
//  Used across the app for consistent game time/status display
//

import SwiftUI

/// **MatchupTeamFinalView**
/// 
/// DRY component for displaying NFL game matchup information with enhanced styling:
/// - Real game times and status from NFLGameDataService
/// - Enhanced FINAL game styling with winning/losing score colors and sizes
/// - Scalable design for different contexts
/// - Consistent across all player cards and roster views
struct MatchupTeamFinalView: View {
    let player: FantasyPlayer
    let scaleEffect: CGFloat
    
    @StateObject private var gameViewModel = NFLGameMatchupViewModel()
    @State private var currentWeek: Int = NFLWeekService.shared.currentWeek
    @StateObject private var nflWeekService = NFLWeekService.shared
    
    /// Initialize with default scale
    init(player: FantasyPlayer) {
        self.player = player
        self.scaleEffect = 1.0
    }
    
    /// Initialize with custom scale
    init(player: FantasyPlayer, scaleEffect: CGFloat) {
        self.player = player
        self.scaleEffect = scaleEffect
    }
    
    var body: some View {
        VStack(spacing: 1) {
            if gameViewModel.isLoading && gameViewModel.gameInfo == nil {
                loadingView
            } else if let gameInfo = gameViewModel.gameInfo {
                gameInfoView(gameInfo)
            } else {
                fallbackTeamView
            }
        }
        .scaleEffect(scaleEffect)
        .onAppear {
            setupGameData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            gameViewModel.refresh(week: currentWeek)
        }
        .onReceive(nflWeekService.$currentWeek) { newWeek in
            if currentWeek != newWeek {
                currentWeek = newWeek
                setupGameData()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.6)
            Text("Loading...")
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
        )
    }
    
    // MARK: - Game Info View
    
    private func gameInfoView(_ gameInfo: NFLGameInfo) -> some View {
        VStack(spacing: 1) {
            // Team matchup
            Text(gameInfo.matchupString)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.8))
                )
                .id(gameInfo.matchupString)
            
            // Game time/status
            Text(gameInfo.formattedGameTime)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    NFLTeam.team(for: player.team ?? "")?.primaryColor ?? gameInfo.statusColor, 
                                    .clear
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .id(gameInfo.formattedGameTime)
            
            // Enhanced score display for live/final games
            if gameInfo.isLive || gameInfo.gameStatus.lowercased().contains("final") || gameInfo.gameStatus.lowercased().contains("post") {
                enhancedScoreView(gameInfo)
            }
        }
        .padding(.trailing, 8)
    }
    
    // MARK: - Enhanced Score View with Win/Loss Styling (.gpGreen/.gpRedPink + Size)
    
    private func enhancedScoreView(_ gameInfo: NFLGameInfo) -> some View {
        let isFinalGame = gameInfo.gameStatus.lowercased().contains("final") || gameInfo.gameStatus.lowercased().contains("post")
        
        return Group {
            if isFinalGame && (gameInfo.homeScore > 0 || gameInfo.awayScore > 0) {
                // FINAL game with scores - enhanced win/lose styling with .gpGreen/.gpRedPink
                let isHomeWinning = gameInfo.homeScore > gameInfo.awayScore
                
                HStack(spacing: 2) {
                    // Away score - winner gets larger size + .gpGreen, loser gets smaller + .gpRedPink
                    Text("\(gameInfo.awayScore)")
                        .font(.system(size: !isHomeWinning ? 10 : 7, weight: !isHomeWinning ? .bold : .medium))
                        .foregroundColor(!isHomeWinning ? .gpGreen : .gpRedPink)
                    
                    Text("-")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Home score - winner gets larger size + .gpGreen, loser gets smaller + .gpRedPink
                    Text("\(gameInfo.homeScore)")
                        .font(.system(size: isHomeWinning ? 10 : 7, weight: isHomeWinning ? .bold : .medium))
                        .foregroundColor(isHomeWinning ? .gpGreen : .gpRedPink)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.8))
                )
                .id(gameInfo.scoreString)
            } else {
                // Live game or final without scores - standard styling
                Text(gameInfo.scoreString)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.gpGreen)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.6))
                    )
                    .id(gameInfo.scoreString)
            }
        }
    }
    
    // MARK: - Fallback Team View
    
    private var fallbackTeamView: some View {
        Group {
            if let team = player.team {
                let teamColor = NFLTeam.team(for: team)?.primaryColor ?? .purple
                
                VStack(spacing: 1) {
                    Text("\(team)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [teamColor.opacity(0.8), .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                    
                    Text("BYE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [teamColor, .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                }
                .padding(.trailing, 8)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupGameData() {
        guard let team = player.team else { return }
        
        currentWeek = nflWeekService.currentWeek
        let currentYear = nflWeekService.currentYear
        
        gameViewModel.configure(for: team, week: currentWeek, year: Int(currentYear) ?? 2024)
    }
    
    private func normalizeTeamAbbreviation(_ team: String) -> String {
        switch team.uppercased() {
        case "WAS": return "WSH"
        default: return team.uppercased()
        }
    }
}

// MARK: - Preview

#Preview {
    let mockPlayer = FantasyPlayer(
        id: "test",
        sleeperID: "test", 
        espnID: nil,
        firstName: "Terry",
        lastName: "McLaurin",
        position: "WR",
        team: "WAS",
        jerseyNumber: "17",
        currentPoints: 12.4,
        projectedPoints: 14.2,
        gameStatus: GameStatus(status: "final"),
        isStarter: true,
        lineupSlot: "WR"
    )
    
    VStack(spacing: 20) {
        MatchupTeamFinalView(player: mockPlayer)
        MatchupTeamFinalView(player: mockPlayer, scaleEffect: 1.2)
    }
    .padding()
    .background(Color.black)
}