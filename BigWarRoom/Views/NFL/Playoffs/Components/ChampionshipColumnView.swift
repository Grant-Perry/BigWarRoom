//
//  ChampionshipColumnView.swift
//  BigWarRoom
//
//  Conference Championship game column
//

import SwiftUI

struct ChampionshipColumnView: View {
   let conference: PlayoffGame.Conference
   let champGame: PlayoffGame?
   let divGame1: PlayoffGame?
   let isReversed: Bool
   let isCurrentSeason: Bool
   let cellWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   let yChampTop: CGFloat
   let yChampBot: CGFloat
   let yChampCenter: CGFloat
   let matchupSpacing: CGFloat
   let onGameTap: (PlayoffGame) -> Void
   
   var body: some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: cellWidth, height: totalContentHeight)
         BracketHeader(text: conference == .afc ? "AFC CHAMP" : "NFC CHAMP")

         if let game = champGame {
            PlayoffChampionshipMatchupView(
               game: game,
               topDivGame: divGame1,
               isReversed: isReversed,
               yChampTop: yChampTop,
               yChampBot: yChampBot,
               headerHeight: headerHeight,
               cellWidth: cellWidth,
               matchupSpacing: matchupSpacing,
               onTap: onGameTap
            )
         } else if isCurrentSeason {
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yChampTop + headerHeight)
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yChampBot + headerHeight)
         }
      }
      .frame(width: cellWidth)
   }
}