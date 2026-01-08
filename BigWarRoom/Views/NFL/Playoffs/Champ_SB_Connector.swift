//
   //  Champ_SB_Connector.swift
   //  BigWarRoom
   //

import SwiftUI

struct Champ_SB_Connector: View {
   let isReversed: Bool
   let src: CGFloat?      // Optional - only draw if championship game exists
   let dst: CGFloat

   var body: some View {
      GeometryReader { geo in
         Path { path in
            guard let src = src else { return }
            
            let w = geo.size.width
            let midX = w / 2

            if isReversed {
               // NFC side (right column) mirrored so it turns into the SB card on the left
               path.move(to: CGPoint(x: w, y: src))          // start at right edge
               path.addLine(to: CGPoint(x: midX, y: src))    // horizontal in
               path.addLine(to: CGPoint(x: midX, y: dst))    // vertical drop/rise
               path.addLine(to: CGPoint(x: 0, y: dst))       // horizontal left into SB column
            } else {
               // AFC side: Left -> Right (unchanged)
               path.move(to: CGPoint(x: 0, y: src))          // start at left edge
               path.addLine(to: CGPoint(x: midX, y: src))    // horizontal out
               path.addLine(to: CGPoint(x: midX, y: dst))    // vertical drop/rise
               path.addLine(to: CGPoint(x: w, y: dst))       // horizontal in
            }
         }
         .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
      }
   }
}