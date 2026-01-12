//
   //  BracketTeamCell.swift
   //  BigWarRoom
   //
   //  Created by Gp. on 1/6/26.
   //  Updated: Shows final scores for completed games with win/loss colors
   //

import SwiftUI

struct BracketTeamCell: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   @Environment(NFLStandingsService.self) private var standingsService
   let team: PlayoffTeam?
   let game: PlayoffGame?  // 🔥 NEW: Optional game for score display
   let isReversed: Bool

   var body: some View {
      let winner = isWinner()
      let isLoser = isLoser()
      
      ZStack {
         // Treat "TBD" teams as nil (empty)
         if let team = team, !isTBDTeam(team) {
            let color = teamAssets.team(for: team.abbreviation)?.primaryColor ?? .gray
            RoundedRectangle(cornerRadius: 6)
               .fill(LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
         } else {
            // Empty Matchup Box
            RoundedRectangle(cornerRadius: 6)
               .fill(
                  LinearGradient(
                     gradient: Gradient(colors: [
                        .gray.opacity(0.15),
                        .clear.opacity(0.15)
                     ]),
                     startPoint: .topLeading,
                     endPoint: .bottomTrailing
                  )
               )
         }

         // 🔥 Winner border - 2px for Super Bowl winner (with glow), 1px for other winners (no glow)
         if winner {
            let isSuperBowl = game?.round == .superBowl
            
            RoundedRectangle(cornerRadius: 6)
               .stroke(Color.gpGreen, lineWidth: isSuperBowl ? 3 : 1)
               .shadow(color: isSuperBowl ? Color.gpGreen.opacity(0.85) : .clear, radius: isSuperBowl ? 12 : 0, x: 0, y: 0)
               .shadow(color: isSuperBowl ? Color.gpGreen.opacity(0.55) : .clear, radius: isSuperBowl ? 22 : 0, x: 0, y: 0)
         } else {
            RoundedRectangle(cornerRadius: 6)
               .stroke(Color.white.opacity(0.35), lineWidth: 1)
         }

         if let team = team, !isTBDTeam(team) {
            // 🔥 UPDATED: Watermark - show COLORED SCORE for any game with scores (active or completed), SEED otherwise
            if let game = game, let score = team.score, score > 0 {
               // Show score as watermark for active/completed games
               // Unified styling: always white, preserve previous transparency per status
               let scoreColor: Color = game.isCompleted
                  ? Color.white.opacity(0.2)
                  : Color.white.opacity(0.4)
               
               Text("\(score)")
                  .font(.system(size: 36, weight: .black))
                  .foregroundColor(scoreColor)
                  .frame(maxWidth: .infinity, alignment: .trailing)
                  .padding(.horizontal, 4)
            } else if let seed = team.seed, seed > 0 {
               // Show seed as watermark for scheduled games (no scores yet)
               HStack(alignment: .top, spacing: 0) {
                  Text("#")
                     .font(.system(size: 18, weight: .black))
                     .foregroundColor(.white.opacity(0.25))
                     .offset(y: -1)
                  Text("\(seed)")
                     .font(.system(size: 36, weight: .black))
                     .foregroundColor(.white.opacity(0.3))
               }
               .frame(maxWidth: .infinity, alignment: .trailing)
               .padding(.horizontal, 4)
            }

            // Content Row
            // Standard order: Logo -> Info -> Spacer
            HStack(spacing: 6) {
               logoView(team: team)
               infoView(team: team)
               Spacer()
            }
            .padding(.horizontal, 6)
         }
      }
      .frame(width: 95, height: 40)
      .opacity(isLoser ? 0.4 : 1.0)
      .environment(\.layoutDirection, .leftToRight)
   }

   private func logoView(team: PlayoffTeam) -> some View {
      Group {
         if let logo = teamAssets.logo(for: team.abbreviation) {
            logo.resizable().scaledToFit()
         } else { Circle().fill(Color.gray.opacity(0.3)) }
      }
      .frame(width: 38, height: 38)
   }

   private func infoView(team: PlayoffTeam) -> some View {
      // 🔥 Check if game has scores (active or completed)
      let hasScores = (game?.status.isLive ?? false) || (game?.isCompleted ?? false)
      
      return VStack(alignment: .leading, spacing: 0) {
		 // Team abbreviation name
//         Text(team.abbreviation.uppercased())
//            .font(.system(size: 10, weight: .heavy))
//            .foregroundColor(.white)
         
         if hasScores {
            // 🔥 SWAPPED: Show #seed where score was (in white, no color coding)
            if let seed = team.seed {
               Text("#\(seed)")
                  .font(.system(size: 10, weight: .bold))
                  .monospacedDigit()
                  .foregroundColor(.white.opacity(0.45))
				  .offset(x: -18, y: 13)
            }
         } else {
            // Show record for scheduled games (no scores yet)
            let record = standingsService.getTeamRecord(for: team.abbreviation)
            Text(record)
               .font(.system(size: 8, weight: .medium))
               .monospacedDigit()
               .foregroundColor(.white.opacity(0.7))
         }
      }
   }
   
   /// Determine if this team won the game
   private func isWinner() -> Bool {
      guard let game = game,
            game.isCompleted,
            let team = team else {
         return false
      }
      
      // 🔥 DEBUG: Log all the values using DebugPrint
      if game.round == .superBowl {
         DebugPrint(mode: .nflData, "🏈 SUPER BOWL WINNER CHECK:")
         DebugPrint(mode: .nflData, "   Team: \(team.abbreviation)")
         DebugPrint(mode: .nflData, "   Team Score: \(team.score ?? -1)")
         DebugPrint(mode: .nflData, "   Home Team: \(game.homeTeam.abbreviation) - Score: \(game.homeTeam.score ?? -1)")
         DebugPrint(mode: .nflData, "   Away Team: \(game.awayTeam.abbreviation) - Score: \(game.awayTeam.score ?? -1)")
      }
      
      // 🔥 ULTRA SIMPLE: Just check if this team has the higher score
      guard let myScore = team.score,
            let homeScore = game.homeTeam.score,
            let awayScore = game.awayTeam.score else {
         DebugPrint(mode: .nflData, "   ❌ Missing scores")
         return false
      }
      
      // Determine the winning score
      let winningScore = max(homeScore, awayScore)
      let didWin = myScore == winningScore && winningScore > 0
      
      if game.round == .superBowl {
         DebugPrint(mode: .nflData, "   Winning Score: \(winningScore)")
         DebugPrint(mode: .nflData, "   Did \(team.abbreviation) win? \(didWin)")
      }
      
      return didWin
   }
   
   /// Determine if this team lost the game
   private func isLoser() -> Bool {
      guard let game = game,
            game.isCompleted,
            let team = team else {
         return false
      }
      
      // If there's a winner and this team isn't the winner, they lost
      guard let myScore = team.score,
            let homeScore = game.homeTeam.score,
            let awayScore = game.awayTeam.score else {
         return false
      }
      
      let winningScore = max(homeScore, awayScore)
      return myScore < winningScore && winningScore > 0
   }
   
   /// Normalize team codes for consistent comparison
   private func normalizeTeamCode(_ code: String) -> String {
      let upper = code.uppercased()
      // Handle Washington variations
      if upper == "WASH" || upper == "WSH" {
         return "WAS"
      }
      return upper
   }
   
   // Helper to check if team is a TBD placeholder
   private func isTBDTeam(_ team: PlayoffTeam) -> Bool {
      return team.abbreviation.uppercased() == "TBD" || 
             team.name.uppercased() == "TBD" ||
             team.abbreviation.isEmpty
   }
}