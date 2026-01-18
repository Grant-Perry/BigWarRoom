//
//  PlayoffGameDetailCard.swift
//  BigWarRoom
//
//  Large matchup card for playoff game detail modal
//

import SwiftUI

struct PlayoffGameDetailCard: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   
   let game: PlayoffGame
   let displayOdds: GameBettingOdds?
   let scoreSize: CGFloat
   let scoreOffset: CGFloat
   
   var body: some View {
      // 🔥 NEW: Log when card renders
      let _ = DebugPrint(mode: .bracketTimer, "🎨 [MODAL RENDER] Game: \(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation), Status: \(game.status.displayText), Away: \(game.awayTeam.score ?? 0), Home: \(game.homeTeam.score ?? 0)")
      let _ = DebugPrint(mode: .bracketTimer, "🎨 [LIVE SITUATION] Has liveSituation: \(game.liveSituation != nil), Down/Dist: \(game.liveSituation?.downDistanceDisplay ?? "N/A")")
      let _ = DebugPrint(mode: .bracketTimer, "🏈 [POSSESSION DEBUG] Possession: \(game.liveSituation?.possession ?? "NIL"), Away: \(game.awayTeam.abbreviation), Home: \(game.homeTeam.abbreviation), isLive: \(game.isLive)")
      
      let awayColor = teamAssets.team(for: game.awayTeam.abbreviation)?.primaryColor ?? .blue
      let homeColor = teamAssets.team(for: game.homeTeam.abbreviation)?.primaryColor ?? .red
      let awayScore = game.awayTeam.score ?? 0
      let homeScore = game.homeTeam.score ?? 0
      let hasScores = game.awayTeam.score != nil && game.homeTeam.score != nil
      
      HStack(spacing: 0) {
         // Away team section (left side)
         PlayoffGameDetailTeamSection(
            team: game.awayTeam,
            teamColor: awayColor,
            score: awayScore,
            hasScores: hasScores,
            scoreSize: scoreSize,
            scoreOffset: scoreOffset,
            displayOdds: displayOdds,
            isLive: game.isLive,
            isCompleted: game.isCompleted,
            alignment: .leading
         )
         
         Spacer()
         
         // Center: Game info
         PlayoffGameDetailInfoSection(game: game)
         
         Spacer()
         
         // Home team section (right side)
         PlayoffGameDetailTeamSection(
            team: game.homeTeam,
            teamColor: homeColor,
            score: homeScore,
            hasScores: hasScores,
            scoreSize: scoreSize,
            scoreOffset: scoreOffset,
            displayOdds: displayOdds,
            isLive: game.isLive,
            isCompleted: game.isCompleted,
            alignment: .trailing
         )
      }
      .padding(.horizontal, 20)
      .frame(height: 100)
      .frame(maxWidth: .infinity)
      .background(
         Rectangle()
            .fill(
               LinearGradient(
                  colors: [
                     awayColor.opacity(0.7),
                     awayColor.opacity(0.5),
                     homeColor.opacity(0.5),
                     homeColor.opacity(0.7)
                  ],
                  startPoint: .leading,
                  endPoint: .trailing
               )
            )
      )
      .overlay(
         Rectangle()
            .stroke(
               LinearGradient(
                  colors: [awayColor, homeColor],
                  startPoint: .leading,
                  endPoint: .trailing
               ),
               lineWidth: 2
            )
      )
      .overlay {
         // 🏈 FOOTBALL OVERLAY
         if game.isLive, let possession = game.liveSituation?.possession, hasScores {
            GeometryReader { geo in
               if possession == game.awayTeam.abbreviation {
                  Text("🏈")
                     .font(.system(size: 20))
                     .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                     .position(x: 130 + scoreOffset, y: 87)
               } else if possession == game.homeTeam.abbreviation {
                  Text("🏈")
                     .font(.system(size: 20))
                     .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                     .position(x: geo.size.width - 130 - scoreOffset, y: 87)
               }
            }
         }
      }
      .clipShape(Rectangle())
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.3), radius: 8)
   }
}

// MARK: - Timeout Indicator View

/// Shows 3 circles representing timeouts remaining (filled = available, empty = used)
struct TimeoutIndicatorView: View {
   let timeoutsRemaining: Int
   
   var body: some View {
      HStack(spacing: 3) {
         ForEach(0..<3, id: \.self) { index in
            Circle()
               .fill(index < timeoutsRemaining ? Color.yellow : Color.gray.opacity(0.3))
               .frame(width: 10, height: 10)
               .overlay(
                  Circle()
                     .stroke(Color.secondary, lineWidth: 1)
               )
         }
      }
   }
}