//
//  WildCardColumnView.swift
//  BigWarRoom
//
//  Wild Card round column display with conference logo
//

import SwiftUI

struct WildCardColumnView: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   
   let conference: PlayoffGame.Conference
   let seeds: [Int: PlayoffTeam]
   let wcGame1: PlayoffGame?
   let wcGame2: PlayoffGame?
   let wcGame3: PlayoffGame?
   let isReversed: Bool
   let isCurrentSeason: Bool
   let cellWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   let yWC1: CGFloat
   let yWC2: CGFloat
   let yWC3: CGFloat
   let matchupSpacing: CGFloat
   let onGameTap: (PlayoffGame) -> Void
   
   var body: some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: cellWidth, height: totalContentHeight)
         
         // Conference logo
         if let confLogo = teamAssets.logo(for: (conference == .afc ? "AFC" : "NFC")) {
            confLogo
               .resizable()
               .aspectRatio(contentMode: .fit)
               .frame(width: 56, height: 56)
               .offset(x: conference == .afc ? 120 : 120, y: -headerHeight - 22)
         } else {
            Text(conference == .afc ? "AFC" : "NFC")
               .font(.custom("BebasNeue-Regular", size: 30))
               .foregroundColor(.white)
               .frame(height: headerHeight, alignment: .top)
               .offset(x: conference == .afc ? 125 : 125, y: -headerHeight - 4)
         }

         BracketHeader(text: "WILD CARD")

         // Wild Card games
         if let game = wcGame1 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC1 + headerHeight)
         } else if isCurrentSeason {
            PlayoffMatchupView(topTeam: seeds[5], bottomTeam: seeds[4], isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC1 + headerHeight)
         }

         if let game = wcGame2 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC2 + headerHeight)
         } else if isCurrentSeason {
            PlayoffMatchupView(topTeam: seeds[6], bottomTeam: seeds[3], isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC2 + headerHeight)
         }

         if let game = wcGame3 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC3 + headerHeight)
         } else if isCurrentSeason {
            PlayoffMatchupView(topTeam: seeds[7], bottomTeam: seeds[2], isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC3 + headerHeight)
         }
      }
      .frame(width: cellWidth)
   }
}