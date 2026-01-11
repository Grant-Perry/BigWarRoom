//
//  DivisionalColumnView.swift
//  BigWarRoom
//
//  Divisional round matchups column
//

import SwiftUI

struct DivisionalColumnView: View {
   let seed1: PlayoffTeam?
   let divGame1: PlayoffGame?
   let divGame2: PlayoffGame?
   let isReversed: Bool
   let isCurrentSeason: Bool
   let cellWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   let yDiv1Top: CGFloat
   let yDiv1Bot: CGFloat
   let yDiv1Center: CGFloat
   let yDiv2Top: CGFloat
   let yDiv2Bot: CGFloat
   let yDiv2Center: CGFloat
   let matchupSpacing: CGFloat
   let onGameTap: (PlayoffGame) -> Void
   
   var body: some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: cellWidth, height: totalContentHeight)
         BracketHeader(text: "DIVISIONAL")
         
         // Divisional Game 1
         if let game = divGame1 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yDiv1Center + headerHeight)
         } else if isCurrentSeason {
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv1Top + headerHeight)
            BracketTeamCell(team: seed1, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv1Bot + headerHeight)
         }

         // Divisional Game 2
         if let game = divGame2 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yDiv2Center + headerHeight)
         } else if isCurrentSeason {
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv2Top + headerHeight)
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv2Bot + headerHeight)
         }
      }
      .frame(width: cellWidth)
   }
}