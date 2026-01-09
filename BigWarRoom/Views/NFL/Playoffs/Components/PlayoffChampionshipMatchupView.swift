//
//  PlayoffChampionshipMatchupView.swift
//  BigWarRoom
//
//  Championship matchup with smart team ordering
//

import SwiftUI

struct PlayoffChampionshipMatchupView: View {
   let game: PlayoffGame
   let topDivGame: PlayoffGame?
   let isReversed: Bool
   let yChampTop: CGFloat
   let yChampBot: CGFloat
   let headerHeight: CGFloat
   let cellWidth: CGFloat
   let matchupSpacing: CGFloat
   let onTap: (PlayoffGame) -> Void
   
   var body: some View {
      let topBracketWinnerAbbr = topDivGame != nil ? getWinner(from: topDivGame!)?.abbreviation : nil
      let isHomeFromTop = topBracketWinnerAbbr != nil && game.homeTeam.abbreviation == topBracketWinnerAbbr
      let isAwayFromTop = topBracketWinnerAbbr != nil && game.awayTeam.abbreviation == topBracketWinnerAbbr
      
      VStack(spacing: matchupSpacing) {
         if isHomeFromTop {
            BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
            BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
         } else if isAwayFromTop {
            BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
            BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
         } else {
            let homeS = game.homeTeam.seed ?? 999
            let awayS = game.awayTeam.seed ?? 999
            if homeS < awayS {
               BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
               BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
            } else {
               BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
               BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
            }
         }
      }
      .position(x: cellWidth/2, y: (yChampTop + yChampBot) / 2 + headerHeight)
      .contentShape(Rectangle())
      .onTapGesture {
         DebugPrint(mode: .nflData, "🎯 Tapped championship game: \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
         onTap(game)
      }
   }
   
   private func getWinner(from game: PlayoffGame) -> PlayoffTeam? {
      guard game.isCompleted else { return nil }
      return (game.homeTeam.score ?? 0 > game.awayTeam.score ?? 0)
         ? game.homeTeam
         : (game.awayTeam.score ?? 0 > game.homeTeam.score ?? 0)
         ? game.awayTeam
         : nil
   }
}