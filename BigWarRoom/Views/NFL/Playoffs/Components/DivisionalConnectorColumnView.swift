//
//  DivisionalConnectorColumnView.swift
//  BigWarRoom
//
//  Connectors from Divisional round to Conference Championship
//

import SwiftUI

struct DivisionalConnectorColumnView: View {
   let divGame1: PlayoffGame?
   let divGame2: PlayoffGame?
   let isReversed: Bool
   let isCurrentSeason: Bool
   let connectorWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   let yDiv1Center: CGFloat
   let yDiv2Center: CGFloat
   let yChampTop: CGFloat
   let yChampBot: CGFloat
   
   var body: some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: connectorWidth, height: totalContentHeight)
         BracketHeader(text: "")
         Div_Champ_Connector(
            isReversed: isReversed,
            src1: (divGame1 != nil || isCurrentSeason) ? yDiv1Center : nil,
            src2: (divGame2 != nil || isCurrentSeason) ? yDiv2Center : nil,
            dst_top: yChampTop,
            dst_bot: yChampBot
         )
         .offset(y: headerHeight)
         .scaleEffect(x: isReversed ? -1 : 1, y: 1)
      }
      .frame(width: connectorWidth)
   }
}