//
   //  NFLLandscapeBracketView.swift
   //  BigWarRoom
   //
   //  Created by Alex, the Expert AI Assistant
   //  Updated: Auto-scaling logic added to fit any screen perfectly.
   //

import SwiftUI

struct NFLLandscapeBracketView: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   let bracket: PlayoffBracket

	  // --- 1. PRECISE LAYOUT CONSTANTS ---
	  // Tuned down slightly to fit iPhone screens better natively
   private let cellWidth: CGFloat = 95
   private let cellHeight: CGFloat = 40
   private let cellSpacing: CGFloat = 4
   private let groupSpacing: CGFloat = 16
   private let headerHeight: CGFloat = 24

	  // Width of the "Connector" columns
   private let connectorWidth: CGFloat = 20

	  // Calculated Height of one "Matchup Block"
   private var matchupHeight: CGFloat {
	  (cellHeight * 2) + cellSpacing
   }

	  // The "Ideal" width of the entire diagram (used for auto-scaling)
	  // (WildCard + Con + Div + Con + Champ) * 2 + Center + Padding
   private var idealTotalWidth: CGFloat {
	  let sideWidth = cellWidth + connectorWidth + cellWidth + connectorWidth + cellWidth
	  let centerWidth = cellWidth + 20
	  return (sideWidth * 2) + centerWidth + 40 // +40 for buffer
   }

   var body: some View {
	  GeometryReader { geo in
		 let availableWidth = geo.size.width
		 let availableHeight = geo.size.height

			// Calculate scale: fit width, but don't scale UP if screen is huge
		 let scaleFactor = min(1.0, availableWidth / idealTotalWidth)

		 ZStack {
			Color.black.ignoresSafeArea()

			VStack(spacing: 0) {
				  // Header
			   Text("\(bracket.season) NFL PLAYOFF PICTURE")
				  .font(.custom("BebasNeue-Regular", size: 32))
				  .foregroundColor(.white)
				  .padding(.top, 10)
				  .padding(.bottom, 5)

				  // The Bracket Content
			   HStack(alignment: .top, spacing: 0) {
					 // --- LEFT SIDE (AFC) ---
				  conferenceSide(conference: .afc, isReversed: false)

					 // --- CENTER (SUPER BOWL) ---
				  superBowlColumn

					 // --- RIGHT SIDE (NFC) ---
				  conferenceSide(conference: .nfc, isReversed: true)
			   }
			   .scaleEffect(scaleFactor) // <--- THE MAGIC FIX
			   .frame(width: idealTotalWidth * scaleFactor, height: availableHeight * 0.8)
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

		 // 1. Wild Card Column
	  let wildCardCol = VStack(spacing: groupSpacing) {
		 header("WILD CARD")
		 matchupPair(seeds[5], seeds[4], isReversed: isReversed)
		 matchupPair(seeds[6], seeds[3], isReversed: isReversed)
		 matchupPair(seeds[7], seeds[2], isReversed: isReversed)
	  }

		 // 2. Connector (WC -> DIV)
	  let wcToDiv = VStack(spacing: groupSpacing) {
		 header("")
		 BracketConnector(type: .fork, isReversed: isReversed, cellHeight: cellHeight, spacing: cellSpacing)
			.frame(height: matchupHeight)
		 BracketConnector(type: .fork, isReversed: isReversed, cellHeight: cellHeight, spacing: cellSpacing)
			.frame(height: matchupHeight)
		 BracketConnector(type: .fork, isReversed: isReversed, cellHeight: cellHeight, spacing: cellSpacing)
			.frame(height: matchupHeight)
	  }
		 .frame(width: connectorWidth)

		 // 3. Divisional Column
	  let divisionalCol = VStack(spacing: groupSpacing) {
		 header("DIVISIONAL")
		 teamCell(nil, isReversed: isReversed)
			.frame(height: matchupHeight)
			.offset(y: cellHeight/2 + cellSpacing/2)
		 teamCell(seed1, isReversed: isReversed)
			.frame(height: matchupHeight)
		 teamCell(nil, isReversed: isReversed)
			.frame(height: matchupHeight)
			.offset(y: -(cellHeight/2 + cellSpacing/2))
	  }

		 // 4. Connector (DIV -> CHAMP)
	  let divToChamp = VStack(spacing: 0) {
		 header("")
		 DivisionalConnector(isReversed: isReversed)
			.frame(height: (matchupHeight * 3) + (groupSpacing * 2))
	  }
		 .frame(width: connectorWidth)

		 // 5. Championship Column
	  let champCol = VStack(spacing: 0) {
		 header(conference == .afc ? "AFC CHAMP" : "NFC CHAMP")
			.frame(width: cellWidth + 10)
		 Spacer()
		 teamCell(nil, isReversed: isReversed)
		 Spacer()
	  }
		 .frame(height: (matchupHeight * 3) + (groupSpacing * 2) + headerHeight)

		 // Assemble Left or Right
	  HStack(spacing: 0) {
		 if isReversed {
			champCol; divToChamp; divisionalCol; wcToDiv; wildCardCol
		 } else {
			wildCardCol; wcToDiv; divisionalCol; divToChamp; champCol
		 }
	  }
   }

	  // MARK: - Super Bowl Column
   private var superBowlColumn: some View {
	  VStack(spacing: 0) {
		 header("SUPER BOWL")
		 Spacer()
		 VStack(spacing: 8) {
			teamCell(nil, isReversed: false)
			Text("VS")
			   .font(.system(size: 10, weight: .heavy))
			   .foregroundColor(.gray)
			teamCell(nil, isReversed: true)
		 }
		 Spacer()
	  }
	  .frame(height: (matchupHeight * 3) + (groupSpacing * 2) + headerHeight)
	  .frame(width: cellWidth + 20)
   }

	  // MARK: - Component Views
   @ViewBuilder
   private func header(_ text: String) -> some View {
	  Text(text)
		 .font(.custom("BebasNeue-Regular", size: 10))
		 .foregroundColor(.gray)
		 .frame(height: headerHeight, alignment: .bottom)
		 .padding(.bottom, 2)
   }

   @ViewBuilder
   private func matchupPair(_ top: PlayoffTeam?, _ bot: PlayoffTeam?, isReversed: Bool) -> some View {
	  VStack(spacing: cellSpacing) {
		 teamCell(top, isReversed: isReversed)
		 teamCell(bot, isReversed: isReversed)
	  }
   }

   @ViewBuilder
   private func teamCell(_ team: PlayoffTeam?, isReversed: Bool) -> some View {
	  ZStack {
		 // Conditionally apply gradient or solid color
		 if let team = team {
			let color = teamColor(for: team.abbreviation)
			RoundedRectangle(cornerRadius: 6)
			   .fill(
				  LinearGradient(
					 gradient: Gradient(colors: [color.opacity(0.8), color]),
					 startPoint: .top,
					 endPoint: .bottom
				  )
			   )
		 } else {
			// Dark Background for empty slots
			RoundedRectangle(cornerRadius: 6)
			   .fill(Color(UIColor.systemGray6).opacity(0.15))
		 }

		 // The original overlay for a nice border effect
		 RoundedRectangle(cornerRadius: 6)
			.stroke(Color.white.opacity(0.1), lineWidth: 0.5)

		 if let team = team {
			HStack(spacing: 6) {
			   if isReversed {
				  Spacer()
				  teamInfo(team, align: .trailing)
				  teamLogo(team)
			   } else {
				  teamLogo(team)
				  teamInfo(team, align: .leading)
				  Spacer()
			   }
			}
			.padding(.horizontal, 4)
		 }
	  }
	  .frame(width: cellWidth, height: cellHeight)
   }

   @ViewBuilder
   private func teamLogo(_ team: PlayoffTeam) -> some View {
	  if let logo = teamAssets.logo(for: team.abbreviation) {
		 logo.resizable().scaledToFit().frame(height: 20)
	  } else {
		 Circle().fill(Color.gray.opacity(0.3)).frame(width: 20, height: 20)
	  }
   }

   @ViewBuilder
   private func teamInfo(_ team: PlayoffTeam, align: HorizontalAlignment) -> some View {
	  VStack(alignment: align, spacing: 0) {
		 Text(team.name.uppercased())
			.font(.system(size: 9, weight: .bold))
			.foregroundColor(.white)
			.lineLimit(1)
		 Text("SEED #\(team.seed ?? 0)")
			.font(.system(size: 6, weight: .medium))
			.foregroundColor(.gray)
	  }
   }

	  // MARK: - Helper Methods
   private func teamColor(for teamCode: String) -> Color {
	  teamAssets.team(for: teamCode)?.primaryColor ?? Color.gray
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

   // MARK: - CUSTOM SHAPES (Unchanged but included for completeness)

struct BracketConnector: View {
   enum ConnectorType { case fork, straight }
   let type: ConnectorType
   let isReversed: Bool
   let cellHeight: CGFloat
   let spacing: CGFloat

   var body: some View {
	  GeometryReader { geo in
		 Path { path in
			let w = geo.size.width
			let h = geo.size.height

			let topY = cellHeight / 2
			let botY = cellHeight + spacing + (cellHeight / 2)
			let midY = h / 2

			path.move(to: CGPoint(x: isReversed ? w : 0, y: topY))

			if type == .fork {
			   path.addLine(to: CGPoint(x: w/2, y: topY))
			   path.addLine(to: CGPoint(x: w/2, y: botY))
			   path.move(to: CGPoint(x: isReversed ? w : 0, y: botY))
			   path.addLine(to: CGPoint(x: w/2, y: botY))
			   path.move(to: CGPoint(x: w/2, y: midY))
			   path.addLine(to: CGPoint(x: isReversed ? 0 : w, y: midY))
			}
		 }
		 .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
	  }
   }
}

struct DivisionalConnector: View {
   let isReversed: Bool

   var body: some View {
	  GeometryReader { geo in
		 Path { path in
			let w = geo.size.width
			let h = geo.size.height

			let topBlockCenter = h * (1/6)
			let centerBlockCenter = h * (3/6)
			let botBlockCenter = h * (5/6)

			let xIn = isReversed ? w : 0
			let xMid = w/2
			let xOut = isReversed ? 0 : w

			path.move(to: CGPoint(x: xIn, y: topBlockCenter))
			path.addLine(to: CGPoint(x: xMid, y: topBlockCenter))
			path.addLine(to: CGPoint(x: xMid, y: botBlockCenter))

			path.move(to: CGPoint(x: xIn, y: botBlockCenter))
			path.addLine(to: CGPoint(x: xMid, y: botBlockCenter))

			path.move(to: CGPoint(x: xMid, y: centerBlockCenter))
			path.addLine(to: CGPoint(x: xOut, y: centerBlockCenter))
		 }
		 .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
	  }
   }
}

//   // MARK: - Preview
//#Preview("Landscape NFL Bracket") {
//    let assets = TeamAssetManager()
//    let mockData = PlayoffBracket(
//        season: 2025,
//        afcGames: [
//             .init(id: "afc1", round: .wildCard, conference: .afc, homeTeam: .init(abbreviation: "PIT", name: "Steelers", seed: 4, score: nil, logoURL: ""), awayTeam: .init(abbreviation: "HOU", name: "Texans", seed: 5, score: nil, logoURL: ""), gameDate: .now, status: .scheduled),
//             .init(id: "afc2", round: .wildCard, conference: .afc, homeTeam: .init(abbreviation: "JAX", name: "Jaguars", seed: 3, score: nil, logoURL: ""), awayTeam: .init(abbreviation: "BUF", name: "Bills", seed: 6, score: nil, logoURL: ""), gameDate: .now, status: .scheduled),
//             .init(id: "afc3", round: .wildCard, conference: .afc, homeTeam: .init(abbreviation: "NE", name: "Patriots", seed: 2, score: nil, logoURL: ""), awayTeam: .init(abbreviation: "LAC", name: "Chargers", seed: 7, score: nil, logoURL: ""), gameDate: .now, status: .scheduled)
//        ],
//        nfcGames: [
//            .init(id: "nfc1", round: .wildCard, conference: .nfc, homeTeam: .init(abbreviation: "CAR", name: "Panthers", seed: 4, score: nil, logoURL: ""), awayTeam: .init(abbreviation: "LAR", name: "Rams", seed: 5, score: nil, logoURL: ""), gameDate: .now, status: .scheduled),
//            .init(id: "nfc2", round: .wildCard, conference: .nfc, homeTeam: .init(abbreviation: "PHI", name: "Eagles", seed: 3, score: nil, logoURL: ""), awayTeam: .init(abbreviation: "SF", name: "49ers", seed: 6, score: nil, logoURL: ""), gameDate: .now, status: .scheduled),
//            .init(id: "nfc3
