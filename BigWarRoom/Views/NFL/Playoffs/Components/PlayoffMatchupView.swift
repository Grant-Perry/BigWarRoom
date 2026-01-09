//
//  PlayoffMatchupView.swift
//  BigWarRoom
//
//  Reusable matchup view for playoff bracket
//

import SwiftUI

struct PlayoffMatchupView: View {
   let game: PlayoffGame?
   let topTeam: PlayoffTeam?
   let bottomTeam: PlayoffTeam?
   let isReversed: Bool
   let matchupSpacing: CGFloat
   let onTap: (PlayoffGame) -> Void
   
   init(
      game: PlayoffGame,
      isReversed: Bool = false,
      matchupSpacing: CGFloat = 6,
      onTap: @escaping (PlayoffGame) -> Void
   ) {
      self.game = game
      self.topTeam = game.awayTeam
      self.bottomTeam = game.homeTeam
      self.isReversed = isReversed
      self.matchupSpacing = matchupSpacing
      self.onTap = onTap
   }
   
   init(
      topTeam: PlayoffTeam?,
      bottomTeam: PlayoffTeam?,
      isReversed: Bool = false,
      matchupSpacing: CGFloat = 6,
      onTap: @escaping (PlayoffGame) -> Void
   ) {
      self.game = nil
      self.topTeam = topTeam
      self.bottomTeam = bottomTeam
      self.isReversed = isReversed
      self.matchupSpacing = matchupSpacing
      self.onTap = onTap
   }
   
   var body: some View {
      VStack(spacing: matchupSpacing) {
         BracketTeamCell(team: topTeam, game: game, isReversed: isReversed)
         BracketTeamCell(team: bottomTeam, game: game, isReversed: isReversed)
      }
      .contentShape(Rectangle())
      .onTapGesture {
         if let game = game {
            DebugPrint(mode: .nflData, "🎯 Tapped game: \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
            onTap(game)
         }
      }
   }
}