   //
   //  Div_Champ_Connector.swift
   //  BigWarRoom
   //

import SwiftUI

struct Div_Champ_Connector: View {
   let isReversed: Bool
   let src1: CGFloat      // Top Divisional Game Center
   let src2: CGFloat      // Bottom Divisional Game Center
   let dst_top: CGFloat   // Top Championship Slot
   let dst_bot: CGFloat   // Bottom Championship Slot

   var body: some View {
	  GeometryReader { geo in
		 Path { path in
			let w = geo.size.width

			if isReversed {
				  // --- NFC SIDE (Right) ---
				  // Draw from Right (w) to Left (0)

				  // 1. Force Top Div (src1) to connect to Top Champ (dst_top)
				  // This FLIPS the previous logic that was sending it to dst_bot
			   drawLink(path: &path, startX: w, startY: src1, endX: 0, endY: dst_top, w: w)

				  // 2. Force Bottom Div (src2) to connect to Bottom Champ (dst_bot)
			   drawLink(path: &path, startX: w, startY: src2, endX: 0, endY: dst_bot, w: w)

			} else {
				  // --- AFC SIDE (Left) ---
				  // Draw from Left (0) to Right (w)

				  // Top -> Top
			   drawLink(path: &path, startX: 0, startY: src1, endX: w, endY: dst_top, w: w)
				  // Bot -> Bot
			   drawLink(path: &path, startX: 0, startY: src2, endX: w, endY: dst_bot, w: w)
			}
		 }
		 .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
	  }
   }

   private func drawLink(path: inout Path, startX: CGFloat, startY: CGFloat, endX: CGFloat, endY: CGFloat, w: CGFloat) {
		 // The elbow break-point is always the center of the connector column
	  let midX = w / 2

	  path.move(to: CGPoint(x: startX, y: startY))
	  path.addLine(to: CGPoint(x: midX, y: startY)) // Horizontal out
	  path.addLine(to: CGPoint(x: midX, y: endY))   // Vertical travel
	  path.addLine(to: CGPoint(x: endX, y: endY))   // Horizontal in
   }
}
