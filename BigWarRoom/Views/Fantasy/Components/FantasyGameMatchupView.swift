//
//  FantasyGameMatchupView.swift
//  BigWarRoom
//
//  Real NFL game matchup information display for fantasy players
//

import SwiftUI

/// Displays real NFL game matchup information for a fantasy player
struct FantasyGameMatchupView: View {
    let player: FantasyPlayer
    
    @StateObject private var gameViewModel = NFLGameMatchupViewModel()
    @State private var currentWeek: Int = NFLWeekService.shared.currentWeek
    @StateObject private var nflWeekService = NFLWeekService.shared
    
    var body: some View {
        VStack(spacing: 1) {
            // Only show loading on initial load, not during refreshes
            if gameViewModel.isLoading && gameViewModel.gameInfo == nil {
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
            } else if let gameInfo = gameViewModel.gameInfo {
                VStack(spacing: 1) {
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
                    
                    Text(gameInfo.formattedGameTime)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [NFLTeam.team(for: player.team ?? "")?.primaryColor ?? gameInfo.statusColor, .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .id(gameInfo.formattedGameTime)
                    
                    if gameInfo.isLive || gameInfo.gameStatus.lowercased().contains("final") || gameInfo.gameStatus.lowercased().contains("post") {
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
                .padding(.trailing, 8)
            } else {
                fallbackTeamView
            }
        }
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
    
    // MARK: - Private Views
    
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
}