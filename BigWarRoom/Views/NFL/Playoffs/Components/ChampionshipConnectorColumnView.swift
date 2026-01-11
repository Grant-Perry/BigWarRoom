//
//  ChampionshipConnectorColumnView.swift
//  BigWarRoom
//
//  Connector from Conference Championship to Super Bowl
//

import SwiftUI

struct ChampionshipConnectorColumnView: View {
   let conference: PlayoffGame.Conference
   let champGame: PlayoffGame?
   let isReversed: Bool
   let isCurrentSeason: Bool
   let connectorWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   let yChampCenter: CGFloat
   
   var body: some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: connectorWidth, height: totalContentHeight)
         BracketHeader(text: "")
         
         if conference == .afc {
            Champ_SB_Connector(
               isReversed: false,
               src: (champGame != nil || isCurrentSeason) ? yChampCenter + headerHeight : nil,
               dst: yChampCenter + headerHeight - 33,
               startOffset: 8
            )
            .frame(width: connectorWidth + 16)
         } else {
            Champ_SB_Connector(
               isReversed: false,
               src: (champGame != nil || isCurrentSeason) ? yChampCenter + headerHeight : nil,
               dst: yChampCenter + headerHeight - 45,
               startOffset: 8
            )
            .frame(width: connectorWidth + 16)
            .offset(x: -6, y: 45)
            .scaleEffect(x: -1, y: 1)
         }
      }
      .frame(width: connectorWidth)
   }
}