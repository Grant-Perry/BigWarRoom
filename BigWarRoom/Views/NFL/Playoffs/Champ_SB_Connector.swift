   //
   //  Champ_SB_Connector.swift
   //  BigWarRoom
   //

import SwiftUI

struct Champ_SB_Connector: View {
   let isReversed: Bool
   let src: CGFloat
   let dst: CGFloat

   var body: some View {
	  GeometryReader { geo in
		 Path { path in
			let w = geo.size.width

			   // Draw standard Left -> Right
			   // (Parent view flips this with .scaleEffect if needed)
			path.move(to: CGPoint(x: 0, y: src))

			let midX = w / 2

			   // Draw line
			path.addLine(to: CGPoint(x: midX, y: src)) // Horizontal out
			path.addLine(to: CGPoint(x: midX, y: dst)) // Vertical drop/rise
			path.addLine(to: CGPoint(x: w, y: dst))    // Horizontal in
		 }
		 .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
	  }
   }
}
