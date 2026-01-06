   //
   //  NFLLandscapeBracketView.swift
   //  BigWarRoom
   //

import SwiftUI

struct NFLLandscapeBracketView: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   @Environment(NFLStandingsService.self) private var standingsService
   let bracket: PlayoffBracket

	  // --- Layout Configuration ---
   private let cellWidth: CGFloat = 95
   private let cellHeight: CGFloat = 40
   private let matchupSpacing: CGFloat = 4      // Gap between teams in one matchup
   private let groupSpacing: CGFloat = 20       // Gap between different matchups
   private let connectorWidth: CGFloat = 30
   private let headerHeight: CGFloat = 24

	  // --- Vertical Coordinate System ---
	  // We calculate Y-positions manually to ensure lines hit exactly where we want.

	  // Height of one matchup block (2 cells + spacing)
   private var matchH: CGFloat { (cellHeight * 2) + matchupSpacing }

	  // 1. Wild Card Centers (Source Points)
	  // WC1 is at the top (y=0 relative to content). Center is half height.
   private var yWC1: CGFloat { matchH / 2 }
	  // WC2 is one full matchup + group spacing down.
   private var yWC2: CGFloat { matchH + groupSpacing + (matchH / 2) }
	  // WC3 is two matchups + two group spacings down.
   private var yWC3: CGFloat { (matchH + groupSpacing) * 2 + (matchH / 2) }

	  // 2. Divisional Slots (Destination Points)
	  // Div 1 Top Slot: Aligns perfectly with WC1 for a straight line.
   private var yDiv1_Top: CGFloat { yWC1 }
	  // Div 1 Bot Slot (#1 Seed): Sits below Top Slot.
   private var yDiv1_Bot: CGFloat { yDiv1_Top + cellHeight + matchupSpacing }
	  // Div 1 Matchup Center (for output line): Average of Top and Bot slots.
   private var yDiv1_Center: CGFloat { (yDiv1_Top + yDiv1_Bot) / 2 }

	  // Div 2 Matchup: Centered between WC2 and WC3 inputs.
	  // The Matchup Center is the average of WC2 and WC3.
   private var yDiv2_Center: CGFloat { (yWC2 + yWC3) / 2 }
	  // Div 2 Top Slot: Above center.
   private var yDiv2_Top: CGFloat { yDiv2_Center - (cellHeight/2) - (matchupSpacing/2) }
	  // Div 2 Bot Slot: Below center.
   private var yDiv2_Bot: CGFloat { yDiv2_Center + (cellHeight/2) + (matchupSpacing/2) }

	  // 3. Championship Slots
	  // Champ Top Slot: Input from Div 1 Center.
	  // Champ Bot Slot: Input from Div 2 Center.
	  // Actually, we want the Champ Matchup to be visually centered relative to the whole block.
	  // Let's center it between Div 1 and Div 2 Centers.
   private var yChamp_Center: CGFloat { (yDiv1_Center + yDiv2_Center) / 2 }
   private var yChamp_Top: CGFloat { yChamp_Center - (cellHeight/2) - (matchupSpacing/2) }
   private var yChamp_Bot: CGFloat { yChamp_Center + (cellHeight/2) + (matchupSpacing/2) }

	  // Total Content Height
   private var totalContentHeight: CGFloat { (matchH * 3) + (groupSpacing * 2) }

	  // --- Zoom State ---
   @State private var steadyZoom: CGFloat = 1.0
   @State private var pinchZoom: CGFloat = 1.0
   @State private var steadyOffset: CGSize = .zero
   @State private var dragOffset: CGSize = .zero

   private var idealTotalWidth: CGFloat {
	  let side = cellWidth + connectorWidth + cellWidth + connectorWidth + cellWidth
	  let center = cellWidth + 50
	  return (side * 2) + center + 60
   }

   var body: some View {
	  GeometryReader { geo in
		 let availableWidth = geo.size.width
		 let availableHeight = geo.size.height

		 let baseScale = min(1.0, availableWidth / idealTotalWidth)
		 let zoomFactor = min(max(steadyZoom * pinchZoom, 1.0), 3.0)
		 let finalScale = baseScale * zoomFactor

		 let totalOffset = CGSize(
			width: steadyOffset.width + dragOffset.width,
			height: steadyOffset.height + dragOffset.height
		 )

		 ZStack {
			Color.black
			   .opacity(0.5)
			   .ignoresSafeArea()


			VStack(spacing: 0) {
				  // Header
			   Text("2025 NFL PLAYOFF PICTURE")
				  .font(.custom("BebasNeue-Regular", size: 32))
				  .foregroundColor(.white)
				  .padding(.top, 20)
				  .padding(.bottom, 10)

				  // Bracket Container
			   HStack(alignment: .top, spacing: 0) {
				  conferenceSide(conference: .afc, isReversed: false)
				  superBowlColumn
				  conferenceSide(conference: .nfc, isReversed: true) // this was true, reverses the seed text
			   }
			   .scaleEffect(finalScale)
			   .offset(totalOffset)
			   .frame(width: idealTotalWidth * baseScale, height: totalContentHeight + headerHeight + 50)
			   .simultaneousGesture(
				  MagnificationGesture()
					 .onChanged { pinchZoom = $0 }
					 .onEnded { steadyZoom = min(max(steadyZoom * $0, 1.0), 3.0); pinchZoom = 1.0 }
			   )
			   .simultaneousGesture(
				  DragGesture()
					 .onChanged { dragOffset = $0.translation }
					 .onEnded { steadyOffset.width += $0.translation.width; steadyOffset.height += $0.translation.height; dragOffset = .zero }
			   )
			}
			.position(x: availableWidth / 2, y: availableHeight / 2)
		 }
	  }
   }

	  // MARK: - Conference Builder
   @ViewBuilder
   private func conferenceSide(conference: PlayoffGame.Conference, isReversed: Bool) -> some View {
	  let seeds = getSeedsForConference(bracket: bracket, conference: conference)
	  let seed1 = conference == .afc ? bracket.afcSeed1 : bracket.nfcSeed1

	  HStack(alignment: .top, spacing: 0) {
			// COL 1: Wild Card
		 ZStack(alignment: .top) {
			Color.clear.frame(width: cellWidth, height: totalContentHeight)

			Text(conference == .afc ? "AFC" : "NFC")
			   .font(.custom("BebasNeue-Regular", size: 20))
			   .foregroundColor(.white)
			   .frame(height: headerHeight, alignment: .top)
			   .offset(y: -headerHeight - 4)


			BracketHeader(text: "WILD CARD")

			   // WC 1
			matchupView(top: seeds[5], bot: seeds[4], isReversed: isReversed)
			   .position(x: cellWidth/2, y: yWC1 + headerHeight)

			   // WC 2
			matchupView(top: seeds[6], bot: seeds[3], isReversed: isReversed)
			   .position(x: cellWidth/2, y: yWC2 + headerHeight)

			   // WC 3
			matchupView(top: seeds[7], bot: seeds[2], isReversed: isReversed)
			   .position(x: cellWidth/2, y: yWC3 + headerHeight)
		 }
		 .frame(width: cellWidth)

			// COL 2: WC -> Div Connectors
		 ZStack(alignment: .top) {
			Color.clear.frame(width: connectorWidth, height: totalContentHeight)
			BracketHeader(text: "")

			WC_Div_Connector(
			   isReversed: isReversed,
			   src1: yWC1, src2: yWC2, src3: yWC3,
			   dst1: yDiv1_Top, dst2_top: yDiv2_Top, dst2_bot: yDiv2_Bot
			)
			.offset(y: headerHeight) // Shift down for header
		 }
		 .frame(width: connectorWidth)

			// COL 3: Divisional
		 ZStack(alignment: .top) {
			Color.clear.frame(width: cellWidth, height: totalContentHeight)
			BracketHeader(text: "DIVISIONAL")

			   // Div 1 (Top Slot Empty, Bot Slot #1)
			BracketTeamCell(team: nil, isReversed: isReversed)
			   .position(x: cellWidth/2, y: yDiv1_Top + headerHeight)
			BracketTeamCell(team: seed1, isReversed: isReversed)
			   .position(x: cellWidth/2, y: yDiv1_Bot + headerHeight)

			   // Div 2 (Both Empty)
			BracketTeamCell(team: nil, isReversed: isReversed)
			   .position(x: cellWidth/2, y: yDiv2_Top + headerHeight)
			BracketTeamCell(team: nil, isReversed: isReversed)
			   .position(x: cellWidth/2, y: yDiv2_Bot + headerHeight)
		 }
		 .frame(width: cellWidth)

			// COL 4: Div -> Champ Connectors
		 ZStack(alignment: .top) {
			Color.clear.frame(width: connectorWidth, height: totalContentHeight)
			BracketHeader(text: "")

			Div_Champ_Connector(
			   isReversed: isReversed,
			   src1: yDiv1_Center, src2: yDiv2_Center,
			   dst_top: yChamp_Top, dst_bot: yChamp_Bot
			)
			.offset(y: headerHeight)
		 }
		 .frame(width: connectorWidth)

			// COL 5: Championship
		 ZStack(alignment: .top) {
			Color.clear.frame(width: cellWidth, height: totalContentHeight)
			BracketHeader(text: conference == .afc ? "AFC CHAMP" : "NFC CHAMP")

			BracketTeamCell(team: nil, isReversed: isReversed)
			   .position(x: cellWidth/2, y: yChamp_Top + headerHeight)
			BracketTeamCell(team: nil, isReversed: isReversed)
			   .position(x: cellWidth/2, y: yChamp_Bot + headerHeight)
		 }
		 .frame(width: cellWidth)
	  }
	  .environment(\.layoutDirection, isReversed ? .rightToLeft : .leftToRight)
   }

	  // MARK: - Super Bowl Column
   private var superBowlColumn: some View {
	  VStack(spacing: 0) {
		 Text("SUPER BOWL")
			.font(.system(size: 18, weight: .heavy)) // Bumped Size
			.foregroundColor(.gpGreen)               // Green Color
			.frame(height: headerHeight, alignment: .bottom)
			.padding(.bottom, 4)

		 ZStack {
			Color.clear.frame(height: totalContentHeight)

			   // Vertically centered in the block
			VStack(spacing: 12) {
			   BracketTeamCell(team: nil, isReversed: false)
			   Text("VS")
				  .font(.system(size: 14, weight: .black))
				  .foregroundColor(.white.opacity(0.5))
			   BracketTeamCell(team: nil, isReversed: true)
			}
		 }
	  }
	  .frame(width: cellWidth + 30)
	  .offset(y: -15)
   }

	  // MARK: - Components

   @ViewBuilder
   private func matchupView(top: PlayoffTeam?, bot: PlayoffTeam?, isReversed: Bool) -> some View {
	  VStack(spacing: matchupSpacing) {
		 BracketTeamCell(team: top, isReversed: isReversed)
		 BracketTeamCell(team: bot, isReversed: isReversed)
	  }
   }

   private func getSeedsForConference(bracket: PlayoffBracket, conference: PlayoffGame.Conference) -> [Int: PlayoffTeam] {
	  var seeds: [Int: PlayoffTeam] = [:]
	  let games = (conference == .afc ? bracket.afcGames : bracket.nfcGames)
	  games.forEach { game in
		 if let awaySeed = game.awayTeam.seed { seeds[awaySeed] = game.awayTeam }
		 if let homeSeed = game.homeTeam.seed { seeds[homeSeed] = game.homeTeam }
	  }
	  if let s1 = (conference == .afc ? bracket.afcSeed1 : bracket.nfcSeed1) { seeds[1] = s1 }
	  return seeds
   }
}

   // MARK: - Connectors

struct WC_Div_Connector: View {
   let isReversed: Bool
   let src1: CGFloat; let src2: CGFloat; let src3: CGFloat
   let dst1: CGFloat; let dst2_top: CGFloat; let dst2_bot: CGFloat

   var body: some View {
	  GeometryReader { geo in
		 Path { path in
			let w = geo.size.width

			   // 1. WC1 -> Div 1 Top (Straight Horizontal)
			drawLink(path: &path, fromY: src1, toY: dst1, w: w, isReversed: false) // isReversed handled by parent env

			   // 2. WC2 -> Div 2 Top (Elbow Down)
			drawLink(path: &path, fromY: src2, toY: dst2_top, w: w, isReversed: false)

			   // 3. WC3 -> Div 2 Bot (Elbow Up)
			drawLink(path: &path, fromY: src3, toY: dst2_bot, w: w, isReversed: false)
		 }
		 .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
	  }
   }
}

struct Div_Champ_Connector: View {
   let isReversed: Bool
   let src1: CGFloat; let src2: CGFloat
   let dst_top: CGFloat; let dst_bot: CGFloat

   var body: some View {
	  GeometryReader { geo in
		 Path { path in
			let w = geo.size.width
			   // 1. Div 1 Center -> Champ Top
			drawLink(path: &path, fromY: src1, toY: dst_top, w: w, isReversed: false)

			   // 2. Div 2 Center -> Champ Bot
			drawLink(path: &path, fromY: src2, toY: dst_bot, w: w, isReversed: false)
		 }
		 .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
	  }
   }
}

   // Helper: Draws horizontal-vertical-horizontal link
private func drawLink(path: inout Path, fromY: CGFloat, toY: CGFloat, w: CGFloat, isReversed: Bool) {
	  // Note: Since we flip the parent HStack layout direction, we always draw Left->Right in local coords
   let startX: CGFloat = 0
   let endX: CGFloat = w
   let midX = w / 2

   path.move(to: CGPoint(x: startX, y: fromY))
   path.addLine(to: CGPoint(x: midX, y: fromY))
   path.addLine(to: CGPoint(x: midX, y: toY))
   path.addLine(to: CGPoint(x: endX, y: toY))
}

   // MARK: - Visuals

struct BracketHeader: View {
   let text: String
   var body: some View {
	  Text(text)
		 .font(.custom("BebasNeue-Regular", size: 12))
		 .foregroundColor(.white.opacity(0.6))
		 .frame(height: 24, alignment: .bottom) // Matches headerHeight
		 .padding(.bottom, 4)
   }
}




