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
   private let matchupSpacing: CGFloat = 4
   private let groupSpacing: CGFloat = 20
   private let connectorWidth: CGFloat = 30
   private let headerHeight: CGFloat = 24

	  // --- Vertical Coordinate System ---
   private var matchH: CGFloat { (cellHeight * 2) + matchupSpacing }

	  // 1. Wild Card Centers
   private var yWC1: CGFloat { matchH / 2 }
   private var yWC2: CGFloat { matchH + groupSpacing + (matchH / 2) }
   private var yWC3: CGFloat { (matchH + groupSpacing) * 2 + (matchH / 2) }

	  // 2. Divisional Slots
   private var yDiv1_Top: CGFloat { yWC1 }
   private var yDiv1_Bot: CGFloat { yDiv1_Top + cellHeight + matchupSpacing }
   private var yDiv1_Center: CGFloat { (yDiv1_Top + yDiv1_Bot) / 2 }

   private var yDiv2_Center: CGFloat { (yWC2 + yWC3) / 2 }
   private var yDiv2_Top: CGFloat { yDiv2_Center - (cellHeight/2) - (matchupSpacing/2) }
   private var yDiv2_Bot: CGFloat { yDiv2_Center + (cellHeight/2) + (matchupSpacing/2) }

	  // 3. Championship Slots
   private var yChamp_Center: CGFloat { (yDiv1_Center + yDiv2_Center) / 2 }
   private var yChamp_Top: CGFloat { yChamp_Center - (cellHeight/2) - (matchupSpacing/2) }
   private var yChamp_Bot: CGFloat { yChamp_Center + (cellHeight/2) + (matchupSpacing/2) }

	  // 4. Super Bowl Coordinates (Calculated for Perfect Alignment)
	  // We want the matchup centered in the view, vertically.
   private var ySB_Matchup_Center: CGFloat { totalContentHeight / 2 }

	  // The AFC Box is above the center. (Half height (20) + Half spacing (6) = 26 up)
   private var ySB_AFC: CGFloat { ySB_Matchup_Center - 26 }

	  // The NFC Box is below the center. (Half height (20) + Half spacing (6) = 26 down)
   private var ySB_NFC: CGFloat { ySB_Matchup_Center + 26 }

   private var totalContentHeight: CGFloat { (matchH * 3) + (groupSpacing * 2) }

	  // --- Zoom State ---
   @State private var steadyZoom: CGFloat = 1.0
   @State private var pinchZoom: CGFloat = 1.0
   @State private var steadyOffset: CGSize = .zero
   @State private var dragOffset: CGSize = .zero

   private var idealTotalWidth: CGFloat {
		 // Width = 2 sides + Center + Extra Spacing
	  let side = cellWidth + connectorWidth + cellWidth + connectorWidth + cellWidth + connectorWidth
	  let center = cellWidth + 50
	  return (side * 2) + center + 60
   }

   var body: some View {
	  GeometryReader { geo in
		 let availableWidth = geo.size.width
		 let availableHeight = geo.size.height
		 let baseScale = min(1.0, availableWidth / idealTotalWidth)
		 let finalScale = baseScale * min(max(steadyZoom * pinchZoom, 1.0), 3.0)
		 let totalOffset = CGSize(width: steadyOffset.width + dragOffset.width, height: steadyOffset.height + dragOffset.height)

		 ZStack {
			Color.black.opacity(0.5).ignoresSafeArea()

			VStack(spacing: 0) {
			   Text("\(String(bracket.season)) NFL PLAYOFF PICTURE")
				  .font(.custom("BebasNeue-Regular", size: 32))
				  .foregroundColor(.white)
				  .padding(.top, 30)
				  .padding(.bottom, 10)

			   HStack(alignment: .top, spacing: 0) {
				  conferenceSide(conference: .afc, isReversed: false)
				  superBowlColumn
				  conferenceSide(conference: .nfc, isReversed: true)
			   }
			   .scaleEffect(finalScale)
			   .offset(totalOffset)
			   .frame(width: idealTotalWidth * baseScale, height: totalContentHeight + headerHeight + 50)
			   .simultaneousGesture(MagnificationGesture().onChanged { pinchZoom = $0 }.onEnded { steadyZoom = min(max(steadyZoom * $0, 1.0), 3.0); pinchZoom = 1.0 })
			   .simultaneousGesture(DragGesture().onChanged { dragOffset = $0.translation }.onEnded { steadyOffset.width += $0.translation.width; steadyOffset.height += $0.translation.height; dragOffset = .zero })
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
	  let games = conference == .afc ? bracket.afcGames : bracket.nfcGames

	  let wildCardGames = games.filter { game in
		 let homeSeed = game.homeTeam.seed ?? 99
		 let awaySeed = game.awayTeam.seed ?? 99
		 return game.round == .wildCard && homeSeed <= 7 && awaySeed <= 7
	  }.sorted { $0.gameDate < $1.gameDate }

	  let allDivisionalGames = games.filter { $0.round == .divisional }.sorted { $0.gameDate < $1.gameDate }
	  let allConferenceGames = games.filter { $0.round == .conference }
	  let divisionalGamesResult = sortDivisionalGames(allDivisionalGames)
	  let divGame1 = divisionalGamesResult.0
	  let divGame2 = divisionalGamesResult.1
	  let champGame = allConferenceGames.first

	  let game_5v4 = findWildCardGame(wildCardGames, highSeed: 4, lowSeed: 5)
	  let game_6v3 = findWildCardGame(wildCardGames, highSeed: 3, lowSeed: 6)
	  let game_7v2 = findWildCardGame(wildCardGames, highSeed: 2, lowSeed: 7)

	  var wcGame1: PlayoffGame?
	  var wcGame2: PlayoffGame?
	  var wcGame3: PlayoffGame?

	  if let dGame = divGame1 {
		 let seedA = dGame.homeTeam.seed ?? 99
		 let opponentAbbr = (seedA == 1) ? dGame.awayTeam.abbreviation : dGame.homeTeam.abbreviation
		 wcGame1 = wildCardGames.first { g in g.homeTeam.abbreviation == opponentAbbr || g.awayTeam.abbreviation == opponentAbbr }
	  }
	  if wcGame1 == nil { wcGame1 = game_5v4 }
	  let allPotentialGames = [game_5v4, game_6v3, game_7v2].compactMap { $0 }
	  let remainingGames = allPotentialGames.filter { $0.id != wcGame1?.id }
	  wcGame2 = remainingGames.first
	  wcGame3 = remainingGames.last

	  return HStack(alignment: .top, spacing: 0) {
			// COL 1: Wild Card
		 ZStack(alignment: .top) {
			Color.clear.frame(width: cellWidth, height: totalContentHeight)
			Text(conference == .afc ? "AFC" : "NFC")
			   .font(.custom("BebasNeue-Regular", size: 30))
			   .foregroundColor(.white)
			   .frame(height: headerHeight, alignment: .top)
			   .offset(x: conference == .afc ? 125 : 125, y: -headerHeight - 4) // center the header

			BracketHeader(text: "WILD CARD")

			if let game = wcGame1 { matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yWC1 + headerHeight) }
			else { matchupView(top: seeds[5], bot: seeds[4], isReversed: isReversed).position(x: cellWidth/2, y: yWC1 + headerHeight) }

			if let game = wcGame2 { matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yWC2 + headerHeight) }
			else { matchupView(top: seeds[6], bot: seeds[3], isReversed: isReversed).position(x: cellWidth/2, y: yWC2 + headerHeight) }

			if let game = wcGame3 { matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yWC3 + headerHeight) }
			else { matchupView(top: seeds[7], bot: seeds[2], isReversed: isReversed).position(x: cellWidth/2, y: yWC3 + headerHeight) }
		 }.frame(width: cellWidth)

			// COL 2: WC -> Div Connectors
		 ZStack(alignment: .top) {
			Color.clear.frame(width: connectorWidth, height: totalContentHeight)
			BracketHeader(text: "")
			WC_Div_Connector(isReversed: isReversed, src1: yWC1, src2: yWC2, src3: yWC3, dst1: yDiv1_Top, dst2_top: yDiv2_Top, dst2_bot: yDiv2_Bot)
			   .offset(y: headerHeight)
		 }.frame(width: connectorWidth)

			// COL 3: Divisional
		 ZStack(alignment: .top) {
			Color.clear.frame(width: cellWidth, height: totalContentHeight)
			BracketHeader(text: "DIVISIONAL")
			if let game = divGame1 { matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yDiv1_Center + headerHeight) }
			else { BracketTeamCell(team: nil, isReversed: isReversed).position(x: cellWidth/2, y: yDiv1_Top + headerHeight); BracketTeamCell(team: seed1, isReversed: isReversed).position(x: cellWidth/2, y: yDiv1_Bot + headerHeight) }

			if let game = divGame2 { matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yDiv2_Center + headerHeight) }
			else { BracketTeamCell(team: nil, isReversed: isReversed).position(x: cellWidth/2, y: yDiv2_Top + headerHeight); BracketTeamCell(team: nil, isReversed: isReversed).position(x: cellWidth/2, y: yDiv2_Bot + headerHeight) }
		 }.frame(width: cellWidth)

			// COL 4: Div -> Champ Connectors
		 ZStack(alignment: .top) {
			Color.clear.frame(width: connectorWidth, height: totalContentHeight)
			BracketHeader(text: "")
			Div_Champ_Connector(
			   isReversed: isReversed,
			   src1: yDiv1_Center,
			   src2: yDiv2_Center,
			   dst_top: yChamp_Top,
			   dst_bot: yChamp_Bot
			)
			.offset(y: headerHeight)
			.scaleEffect(x: isReversed ? -1 : 1, y: 1)
		 }.frame(width: connectorWidth)

			// COL 5: Championship
		 ZStack(alignment: .top) {
			Color.clear.frame(width: cellWidth, height: totalContentHeight)
			BracketHeader(text: conference == .afc ? "AFC CHAMP" : "NFC CHAMP")

			if let game = champGame {
			   championshipMatchupView(game: game, topDivGame: divGame1, isReversed: isReversed)
			} else {
			   BracketTeamCell(team: nil, isReversed: isReversed).position(x: cellWidth/2, y: yChamp_Top + headerHeight)
			   BracketTeamCell(team: nil, isReversed: isReversed).position(x: cellWidth/2, y: yChamp_Bot + headerHeight)
			}
		 }.frame(width: cellWidth)

			// COL 6: Champ -> Super Bowl Connector
		 ZStack(alignment: .top) {
			Color.clear.frame(width: connectorWidth, height: totalContentHeight)
			BracketHeader(text: "")
			Champ_SB_Connector(
			   isReversed: isReversed,
			   src: yChamp_Center + headerHeight,
			   dst: (conference == .afc ? ySB_AFC : ySB_NFC) + headerHeight // Use the exact targets
			)
			.scaleEffect(x: isReversed ? -1 : 1, y: 1)
		 }.frame(width: connectorWidth)
	  }
	  .environment(\.layoutDirection, isReversed ? .rightToLeft : .leftToRight)
   }

	  // MARK: - Super Bowl Column
   private var superBowlColumn: some View {
	  VStack(spacing: 0) {
		 Text("SUPER BOWL")
			.font(.system(size: 18, weight: .heavy))
			.foregroundColor(.gpGreen)
			.frame(height: headerHeight, alignment: .bottom)
			.padding(.bottom, 10)

		 ZStack {
			Color.clear.frame(height: totalContentHeight)

			   // --- Data Prep ---
			let afcChampGame = bracket.afcGames.filter { $0.round == .conference }.first
			let nfcChampGame = bracket.nfcGames.filter { $0.round == .conference }.first
			let afcWinner = afcChampGame != nil ? getWinner(from: afcChampGame!) : nil
			let nfcWinner = nfcChampGame != nil ? getWinner(from: nfcChampGame!) : nil
			let sbGame = bracket.superBowl

			let afcTeam = (sbGame != nil && !isGenericTeam(sbGame!.awayTeam.abbreviation)) ? (isAFCTeam(sbGame!.awayTeam.abbreviation) ? sbGame!.awayTeam : sbGame!.homeTeam) : afcWinner
			let nfcTeam = (sbGame != nil && !isGenericTeam(sbGame!.awayTeam.abbreviation)) ? (isAFCTeam(sbGame!.awayTeam.abbreviation) ? sbGame!.homeTeam : sbGame!.awayTeam) : nfcWinner

			   // --- 1. Champion Box (Moved to TOP) ---
			if let sbGame = sbGame, sbGame.isCompleted {
			   let sbWinner = getWinner(from: sbGame)
			   let actualWinner = (sbWinner != nil && !isGenericTeam(sbWinner!.abbreviation)) ? sbWinner : (sbGame.homeTeam.score ?? 0 > sbGame.awayTeam.score ?? 0) ? (isAFCTeam(sbGame.homeTeam.abbreviation) ? afcTeam : nfcTeam) : (isAFCTeam(sbGame.awayTeam.abbreviation) ? afcTeam : nfcTeam)

			   if let winner = actualWinner {
				  VStack(spacing: 4) {
					 Text("CHAMPION")
						.font(.system(size: 12, weight: .black))
						.foregroundColor(.gpGreen)
						.offset(y: -8)

					 BracketTeamCell(team: winner, isReversed: false)
						.overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.clear, lineWidth: 3))
						.scaleEffect(1.3)
				  }
					 // Position this near the top, under the header
				  .position(x: (cellWidth + 30)/2, y: 50)
			   }
			}

			   // --- 2. Super Bowl Matchup (Centered) ---
			   // We use specific positions so the lines connect perfectly

			   // AFC Team (Top of Stack)
			Group {
			   let offSpace: CGFloat = 10
			   BracketTeamCell(team: afcTeam, isReversed: false)
				  .position(x: (cellWidth + 30)/2, y: ySB_AFC + headerHeight - offSpace)

				  // VS Text (Center) - VS is centered between the two teams
			   Text("VS")
				  .font(.system(size: 14, weight: .black))
				  .padding() // added to give some space
				  .foregroundColor(.white.opacity(0.5))
				  .position(x: (cellWidth + 30)/2, y: ySB_Matchup_Center + headerHeight)

				  // NFC Team (Bottom of Stack)
			   BracketTeamCell(team: nfcTeam, isReversed: true)
				  .position(x: (cellWidth + 30)/2, y: ySB_NFC + headerHeight + offSpace)
			}
			.offset(y: -10)
		 }
		 .offset(y: -23)
	  }
	  .frame(width: cellWidth + 30)
	  .offset(y: -15)
   }

	  // MARK: - Components (Helpers)
   @ViewBuilder private func matchupView(top: PlayoffTeam?, bot: PlayoffTeam?, isReversed: Bool) -> some View { VStack(spacing: matchupSpacing) { BracketTeamCell(team: top, isReversed: isReversed); BracketTeamCell(team: bot, isReversed: isReversed) } }
   @ViewBuilder private func matchupView(game: PlayoffGame, isReversed: Bool) -> some View { VStack(spacing: matchupSpacing) { BracketTeamCell(team: game.awayTeam, isReversed: isReversed); BracketTeamCell(team: game.homeTeam, isReversed: isReversed) } }
   @ViewBuilder private func championshipMatchupView(game: PlayoffGame, topDivGame: PlayoffGame?, isReversed: Bool) -> some View {
	  let topBracketWinnerAbbr = topDivGame != nil ? getWinner(from: topDivGame!)?.abbreviation : nil
	  let isHomeFromTop = topBracketWinnerAbbr != nil && game.homeTeam.abbreviation == topBracketWinnerAbbr
	  let isAwayFromTop = topBracketWinnerAbbr != nil && game.awayTeam.abbreviation == topBracketWinnerAbbr
	  VStack(spacing: matchupSpacing) {
		 if isHomeFromTop { BracketTeamCell(team: game.homeTeam, isReversed: isReversed); BracketTeamCell(team: game.awayTeam, isReversed: isReversed) }
		 else if isAwayFromTop { BracketTeamCell(team: game.awayTeam, isReversed: isReversed); BracketTeamCell(team: game.homeTeam, isReversed: isReversed) }
		 else { let homeS = game.homeTeam.seed ?? 999; let awayS = game.awayTeam.seed ?? 999; if homeS < awayS { BracketTeamCell(team: game.homeTeam, isReversed: isReversed); BracketTeamCell(team: game.awayTeam, isReversed: isReversed) } else { BracketTeamCell(team: game.awayTeam, isReversed: isReversed); BracketTeamCell(team: game.homeTeam, isReversed: isReversed) } }
	  }.position(x: cellWidth/2, y: (yChamp_Top + yChamp_Bot) / 2 + headerHeight)
   }

	  // Helpers
   private func getSeedsForConference(bracket: PlayoffBracket, conference: PlayoffGame.Conference) -> [Int: PlayoffTeam] {
	  var seeds: [Int: PlayoffTeam] = [:]
	  let games = (conference == .afc ? bracket.afcGames : bracket.nfcGames)
	  games.forEach { game in
		 if let awaySeed = game.awayTeam.seed { seeds[awaySeed] = PlayoffTeam(abbreviation: normalizeTeamCode(game.awayTeam.abbreviation), name: game.awayTeam.name, seed: awaySeed, score: game.awayTeam.score, logoURL: game.awayTeam.logoURL) }
		 if let homeSeed = game.homeTeam.seed { seeds[homeSeed] = PlayoffTeam(abbreviation: normalizeTeamCode(game.homeTeam.abbreviation), name: game.homeTeam.name, seed: homeSeed, score: game.homeTeam.score, logoURL: game.homeTeam.logoURL) }
	  }
	  if let s1 = (conference == .afc ? bracket.afcSeed1 : bracket.nfcSeed1) { seeds[1] = PlayoffTeam(abbreviation: normalizeTeamCode(s1.abbreviation), name: s1.name, seed: s1.seed, score: s1.score, logoURL: s1.logoURL) }
	  return seeds
   }
   private func sortDivisionalGames(_ games: [PlayoffGame]) -> (PlayoffGame?, PlayoffGame?) { var divGame1: PlayoffGame? = nil; var divGame2: PlayoffGame? = nil; for game in games { let homeS = game.homeTeam.seed ?? 0; let awayS = game.awayTeam.seed ?? 0; if homeS == 1 || awayS == 1 { divGame1 = game } else { divGame2 = game } }; return (divGame1, divGame2) }
   private func findWildCardGame(_ games: [PlayoffGame], highSeed: Int, lowSeed: Int) -> PlayoffGame? { return games.first { game in let homeS = game.homeTeam.seed ?? 0; let awayS = game.awayTeam.seed ?? 0; return (homeS == highSeed && awayS == lowSeed) || (homeS == lowSeed && awayS == highSeed) } }
   private func normalizeTeamCode(_ code: String) -> String { return (code == "WASH" || code == "WSH") ? "WSH" : code }
   private func getWinner(from game: PlayoffGame) -> PlayoffTeam? { guard game.isCompleted else { return nil }; return (game.homeTeam.score ?? 0 > game.awayTeam.score ?? 0) ? game.homeTeam : (game.awayTeam.score ?? 0 > game.homeTeam.score ?? 0) ? game.awayTeam : nil }
   private func isAFCTeam(_ abbr: String) -> Bool { return NFLTeam.team(for: abbr)?.conference == .afc }
   private func isGenericTeam(_ abbr: String) -> Bool { return abbr == "AFC" || abbr == "NFC" || abbr.isEmpty }
}
