//
//  WildCardConnectorColumnView.swift
//  BigWarRoom
//
//  Connectors from Wild Card round to Divisional round
//

import SwiftUI

struct WildCardConnectorColumnView: View {
   let wcGame1: PlayoffGame?
   let wcGame2: PlayoffGame?
   let wcGame3: PlayoffGame?
   let isReversed: Bool
   let isCurrentSeason: Bool
   let connectorWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   let yWC1: CGFloat
   let yWC2: CGFloat
   let yWC3: CGFloat
   let yDiv1Top: CGFloat
   let yDiv2Top: CGFloat
   let yDiv2Bot: CGFloat
   
   var body: some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: connectorWidth, height: totalContentHeight)
         BracketHeader(text: "")
         WC_Div_Connector(
            isReversed: isReversed,
            src1: (wcGame1 != nil || isCurrentSeason) ? yWC1 : nil,
            src2: (wcGame2 != nil || isCurrentSeason) ? yWC2 : nil,
            src3: (wcGame3 != nil || isCurrentSeason) ? yWC3 : nil,
            dst1: yDiv1Top,
            dst2_top: yDiv2Top,
            dst2_bot: yDiv2Bot
         )
         .offset(y: headerHeight)
      }
      .frame(width: connectorWidth)
   }
}