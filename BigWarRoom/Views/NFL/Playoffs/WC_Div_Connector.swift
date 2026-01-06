//
//  WC_Div_Connector.swift
//  BigWarRoom
//
//  Wild Card to Divisional connector lines
//

import SwiftUI

struct WC_Div_Connector: View {
   let isReversed: Bool
   let src1: CGFloat
   let src2: CGFloat
   let src3: CGFloat
   let dst1: CGFloat
   let dst2_top: CGFloat
   let dst2_bot: CGFloat

   var body: some View {
      GeometryReader { geo in
         Path { path in
            let w = geo.size.width

            // 1. WC1 -> Div 1 Top (Straight Horizontal)
            drawLink(path: &path, fromY: src1, toY: dst1, w: w)

            // 2. WC2 -> Div 2 Top (Elbow Down)
            drawLink(path: &path, fromY: src2, toY: dst2_top, w: w)

            // 3. WC3 -> Div 2 Bot (Elbow Up)
            drawLink(path: &path, fromY: src3, toY: dst2_bot, w: w)
         }
         .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
      }
   }
   
   private func drawLink(path: inout Path, fromY: CGFloat, toY: CGFloat, w: CGFloat) {
      let startX: CGFloat = 0
      let endX: CGFloat = w
      let midX = w / 2

      path.move(to: CGPoint(x: startX, y: fromY))
      path.addLine(to: CGPoint(x: midX, y: fromY))
      path.addLine(to: CGPoint(x: midX, y: toY))
      path.addLine(to: CGPoint(x: endX, y: toY))
   }
}