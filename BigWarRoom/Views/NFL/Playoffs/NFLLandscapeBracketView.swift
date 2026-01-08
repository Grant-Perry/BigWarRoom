//
//   NFLLandscapeBracketView.swift
//   BigWarRoom
//

import SwiftUI

struct NFLLandscapeBracketView: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   @Environment(NFLStandingsService.self) private var standingsService
   let bracket: PlayoffBracket
   let playoffService: NFLPlayoffBracketService?

   @State private var yearManager = SeasonYearManager.shared
   @State private var selectedGame: PlayoffGame?
   @State private var showingGameDetail = false

   private let cellWidth: CGFloat = 95
   private let cellHeight: CGFloat = 40
   private let matchupSpacing: CGFloat = 6
   private let groupSpacing: CGFloat = 20
   private let connectorWidth: CGFloat = 30
   private let headerHeight: CGFloat = 24
   private let sbCardYOffset: CGFloat = 10
   private let sbGroupYOffset: CGFloat = -10
   private let sbScale: CGFloat = 1.15
   private var sbInsetX: CGFloat {
      15 + (cellWidth * (sbScale - 1.0)) / 2
   }

   private var matchH: CGFloat { (cellHeight * 2) + matchupSpacing }

   private var yWC1: CGFloat { matchH / 2 }
   private var yWC2: CGFloat { matchH + groupSpacing + (matchH / 2) }
   private var yWC3: CGFloat { (matchH + groupSpacing) * 2 + (matchH / 2) }

   private var yDiv1_Top: CGFloat { yWC1 }
   private var yDiv1_Bot: CGFloat { yDiv1_Top + cellHeight + matchupSpacing }
   private var yDiv1_Center: CGFloat { (yDiv1_Top + yDiv1_Bot) / 2 }

   private var yDiv2_Center: CGFloat { (yWC2 + yWC3) / 2 }
   private var yDiv2_Top: CGFloat { yDiv2_Center - (cellHeight/2) - (matchupSpacing/2) }
   private var yDiv2_Bot: CGFloat { yDiv2_Center + (cellHeight/2) + (matchupSpacing/2) }

   private var yChamp_Center: CGFloat { (yDiv1_Center + yDiv2_Center) / 2 }
   private var yChamp_Top: CGFloat { yChamp_Center - (cellHeight/2) - (matchupSpacing/2) }
   private var yChamp_Bot: CGFloat { yChamp_Center + (cellHeight/2) + (matchupSpacing/2) }

   private var ySB_Matchup_Center: CGFloat { totalContentHeight / 2 }
   private var ySB_AFC: CGFloat { ySB_Matchup_Center - 26 }
   private var ySB_NFC: CGFloat { ySB_Matchup_Center + 26 }

   private var totalContentHeight: CGFloat { (matchH * 3) + (groupSpacing * 2) }

   private var idealTotalWidth: CGFloat {
      let side = cellWidth + connectorWidth + cellWidth + connectorWidth + cellWidth + connectorWidth
      let center = cellWidth + 50
      return (side * 2) + center + 60
   }

   var body: some View {
      GeometryReader { geo in
         let availableWidth = geo.size.width
         let availableHeight = geo.size.height
         
         // Calculate scale to fit both dimensions (with padding for safe areas)
         let widthScale = (availableWidth - 40) / idealTotalWidth
         let heightScale = (availableHeight - 180) / (totalContentHeight + headerHeight + 50)
         let finalScale = min(widthScale, heightScale, 1.0)
         
         // Dynamic header font size based on screen width
         let headerFontSize: CGFloat = availableWidth < 700 ? 24 : 32
         let topPadding: CGFloat = availableWidth < 700 ? 20 : 45
         let bottomPadding: CGFloat = availableWidth < 700 ? 10 : 20

         ZStack {
            Image("BG3")
               .resizable()
               .aspectRatio(contentMode: .fill)
               .opacity(0.25)
               .ignoresSafeArea()

            VStack(spacing: 0) {
               Menu {
                  ForEach((2012...2026).reversed(), id: \.self) { year in
                     Button(action: {
                        yearManager.selectedYear = String(year)
                     }) {
                        HStack {
                           Text(String(year))
                           if String(year) == yearManager.selectedYear {
                              Image(systemName: "checkmark")
                           }
                        }
                     }
                  }
			   } label: {
				  (
					 Text("\(yearManager.selectedYear) ")
						.foregroundColor(.gpScheduledTop)
					 +
					 Text("NFL PLAYOFF BRACKET")
						.foregroundColor(.white)
				  )
				  .font(.custom("BebasNeue-Regular", size: headerFontSize))
				  .contentShape(Rectangle())
			   }
               .padding(.top, topPadding)
               .padding(.bottom, bottomPadding)
               .zIndex(10)

               HStack(alignment: .top, spacing: 0) {
                  conferenceSide(conference: .afc, isReversed: false)
                  superBowlColumn
                  conferenceSide(conference: .nfc, isReversed: true)
               }
               .scaleEffect(1.1)
               .scaleEffect(finalScale)
               .frame(width: idealTotalWidth * finalScale, height: (totalContentHeight + headerHeight + 50) * finalScale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
         }
         
         // Custom modal overlay instead of sheet
         if showingGameDetail, let game = selectedGame {
            ZStack {
               // Dimmed background
               Color.black.opacity(0.4)
                  .ignoresSafeArea()
                  .onTapGesture {
                     showingGameDetail = false
                     selectedGame = nil
                  }
               
               // Modal card
               VStack(spacing: 0) {
                  // Header
                  HStack {
                     Text(game.round.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                     
                     Spacer()
                     
                     Button {
                        showingGameDetail = false
                        selectedGame = nil
                     } label: {
                        Image(systemName: "xmark.circle.fill")
                           .font(.title2)
                           .foregroundStyle(.white.opacity(0.7))
                     }
                  }
                  .padding()
                  .background(Color(.systemGray6))
                  
                  // Matchup Card (exactly like week 1-18)
                  matchupCardView(game: game)
                     .padding()
                  
                  // Odds section only
                  VStack(alignment: .leading, spacing: 12) {
                     let gameID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
                     let odds = playoffService?.gameOdds[gameID]
                     
                     if let odds = odds {
                        oddsRow(odds: odds)
                     } else {
                        HStack(alignment: .top, spacing: 12) {
                           Image(systemName: "dollarsign.circle")
                              .font(.title3)
                              .foregroundStyle(.secondary)
                              .frame(width: 24)
                           
                           VStack(alignment: .leading, spacing: 4) {
                              Text("Odds")
                                 .font(.subheadline)
                                 .foregroundStyle(.secondary)
                              
                              Text("Not available yet - check back")
                                 .font(.caption)
                                 .foregroundStyle(.secondary.opacity(0.7))
                           }
                           
                           Spacer()
                        }
                     }
                  }
                  .padding()
                  .background(Color(.secondarySystemGroupedBackground))
                  .cornerRadius(12)
                  .padding(.horizontal)
                  .padding(.top, 8)
                  .padding(.bottom, 16)
               }
               .frame(width: 500)
               .fixedSize(horizontal: false, vertical: true)
               .background(Color(.systemBackground))
               .cornerRadius(20)
               .shadow(color: .black.opacity(0.3), radius: 20)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: showingGameDetail)
         }
      }
   }

   @ViewBuilder
   private func conferenceSide(conference: PlayoffGame.Conference, isReversed: Bool) -> some View {
      let seeds = getSeedsForConference(bracket: bracket, conference: conference)
      let seed1 = conference == .afc ? bracket.afcSeed1 : bracket.nfcSeed1
      let games = conference == .afc ? bracket.afcGames : bracket.nfcGames
      
      // 🔥 FIXED: Compare against ACTUAL current season, not selected year
      let actualCurrentSeasonYear = NFLWeekCalculator.getCurrentSeasonYear()
      let isCurrentSeason = (bracket.season == actualCurrentSeasonYear)

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

      // 🔥 DEBUG: Log what games we found
      DebugPrint(mode: .nflData, "🏈 2012 WC Games - 5v4: \(game_5v4 != nil), 6v3: \(game_6v3 != nil), 7v2: \(game_7v2 != nil)")
      DebugPrint(mode: .nflData, "🏈 2012 Total wildCardGames: \(wildCardGames.count)")

      if let dGame = divGame1 {
         let seedA = dGame.homeTeam.seed ?? 99
         let opponentAbbr = (seedA == 1) ? dGame.awayTeam.abbreviation : dGame.homeTeam.abbreviation
         wcGame1 = wildCardGames.first { g in g.homeTeam.abbreviation == opponentAbbr || g.awayTeam.abbreviation == opponentAbbr }
      }
      if wcGame1 == nil { wcGame1 = game_5v4 }
      let allPotentialGames = [game_5v4, game_6v3, game_7v2].compactMap { $0 }
      let remainingGames = allPotentialGames.filter { $0.id != wcGame1?.id }
      
      // 🔥 FIXED: Only assign if games actually exist
      if remainingGames.count >= 1 {
         wcGame2 = remainingGames[0]
      }
      if remainingGames.count >= 2 {
         wcGame3 = remainingGames[1]
      }
      
      // 🔥 DEBUG: Log final assignment AND what will render
      DebugPrint(mode: .nflData, "🏈 \(bracket.season) Final - wcGame1: \(wcGame1 != nil), wcGame2: \(wcGame2 != nil), wcGame3: \(wcGame3 != nil)")
      DebugPrint(mode: .nflData, "🎨 \(bracket.season) Render WC1: \(wcGame1 != nil || isCurrentSeason), WC2: \(wcGame2 != nil || isCurrentSeason), WC3: \(wcGame3 != nil || isCurrentSeason)")
      DebugPrint(mode: .nflData, "🎨 \(bracket.season) isCurrentSeason: \(isCurrentSeason)")

      return HStack(alignment: .top, spacing: 0) {
         ZStack(alignment: .top) {
            Color.clear.frame(width: cellWidth, height: totalContentHeight)
            // Use conference logo (AFC/NFC) instead of text; slightly larger for prominence
            if let confLogo = teamAssets.logo(for: (conference == .afc ? "AFC" : "NFC")) {
               confLogo
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 56, height: 56)
                  .offset(x: conference == .afc ? 120 : 120, y: -headerHeight - 22)
            } else {
               // Fallback to text if logo unavailable
               Text(conference == .afc ? "AFC" : "NFC")
                  .font(.custom("BebasNeue-Regular", size: 30))
                  .foregroundColor(.white)
                  .frame(height: headerHeight, alignment: .top)
                  .offset(x: conference == .afc ? 125 : 125, y: -headerHeight - 4)
            }

            BracketHeader(text: "WILD CARD")

            // 🔥 ONLY render Wild Card games if they exist (or if current season to show empty bracket)
            if let game = wcGame1 {
               matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yWC1 + headerHeight)
            } else if isCurrentSeason {
               matchupView(top: seeds[5], bot: seeds[4], isReversed: isReversed).position(x: cellWidth/2, y: yWC1 + headerHeight)
            }

            if let game = wcGame2 {
               matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yWC2 + headerHeight)
            } else if isCurrentSeason {
               matchupView(top: seeds[6], bot: seeds[3], isReversed: isReversed).position(x: cellWidth/2, y: yWC2 + headerHeight)
            }

            if let game = wcGame3 {
               matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yWC3 + headerHeight)
            } else if isCurrentSeason {
               matchupView(top: seeds[7], bot: seeds[2], isReversed: isReversed).position(x: cellWidth/2, y: yWC3 + headerHeight)
            }
         }.frame(width: cellWidth)

         ZStack(alignment: .top) {
            Color.clear.frame(width: connectorWidth, height: totalContentHeight)
            BracketHeader(text: "")
            WC_Div_Connector(
               isReversed: isReversed, 
               src1: (wcGame1 != nil || isCurrentSeason) ? yWC1 : nil,
               src2: (wcGame2 != nil || isCurrentSeason) ? yWC2 : nil,
               src3: (wcGame3 != nil || isCurrentSeason) ? yWC3 : nil,
               dst1: yDiv1_Top, 
               dst2_top: yDiv2_Top, 
               dst2_bot: yDiv2_Bot
            )
               .offset(y: headerHeight)
         }.frame(width: connectorWidth)

         ZStack(alignment: .top) {
            Color.clear.frame(width: cellWidth, height: totalContentHeight)
            BracketHeader(text: "DIVISIONAL")
            
            // 🔥 Divisional Game 1: Only render if exists (or current season)
            if let game = divGame1 {
               matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yDiv1_Center + headerHeight)
            } else if isCurrentSeason {
               BracketTeamCell(team: nil, game: nil, isReversed: isReversed).position(x: cellWidth/2, y: yDiv1_Top + headerHeight)
               BracketTeamCell(team: seed1, game: nil, isReversed: isReversed).position(x: cellWidth/2, y: yDiv1_Bot + headerHeight)
            }

            // 🔥 Divisional Game 2: Only render if exists (or current season)
            if let game = divGame2 {
               matchupView(game: game, isReversed: isReversed).position(x: cellWidth/2, y: yDiv2_Center + headerHeight)
            } else if isCurrentSeason {
               BracketTeamCell(team: nil, game: nil, isReversed: isReversed).position(x: cellWidth/2, y: yDiv2_Top + headerHeight)
               BracketTeamCell(team: nil, game: nil, isReversed: isReversed).position(x: cellWidth/2, y: yDiv2_Bot + headerHeight)
            }
         }.frame(width: cellWidth)

         ZStack(alignment: .top) {
            Color.clear.frame(width: connectorWidth, height: totalContentHeight)
            BracketHeader(text: "")
            Div_Champ_Connector(
               isReversed: isReversed,
               src1: divGame1 != nil ? yDiv1_Center : nil,
               src2: divGame2 != nil ? yDiv2_Center : nil,
               dst_top: yChamp_Top,
               dst_bot: yChamp_Bot
            )
            .offset(y: headerHeight)
            .scaleEffect(x: isReversed ? -1 : 1, y: 1)
         }.frame(width: connectorWidth)

         ZStack(alignment: .top) {
            Color.clear.frame(width: cellWidth, height: totalContentHeight)
            BracketHeader(text: conference == .afc ? "AFC CHAMP" : "NFC CHAMP")

            // 🔥 Conference Championship: Only render if exists (or current season)
            if let game = champGame {
               championshipMatchupView(game: game, topDivGame: divGame1, isReversed: isReversed)
            } else if isCurrentSeason {
               BracketTeamCell(team: nil, game: nil, isReversed: isReversed).position(x: cellWidth/2, y: yChamp_Top + headerHeight)
               BracketTeamCell(team: nil, game: nil, isReversed: isReversed).position(x: cellWidth/2, y: yChamp_Bot + headerHeight)
            }
         }.frame(width: cellWidth)

         ZStack(alignment: .top) {
            Color.clear.frame(width: connectorWidth, height: totalContentHeight)
            BracketHeader(text: "")
            
            if conference == .afc {
               Champ_SB_Connector(
                  isReversed: false,
                  src: champGame != nil ? yChamp_Center + headerHeight : nil,
                  dst: ySB_AFC + headerHeight + sbGroupYOffset - 23
               )
            } else {
               Champ_SB_Connector(
                  isReversed: false,
                  src: champGame != nil ? yChamp_Center + headerHeight : nil,
                  dst: ySB_AFC + headerHeight + sbGroupYOffset - 23
               )
               .scaleEffect(x: -1, y: 1)
			   .offset(y: 45)
            }
         }.frame(width: connectorWidth)
      }
      .environment(\.layoutDirection, isReversed ? .rightToLeft : .leftToRight)
   }

   private var superBowlColumn: some View {
      VStack(spacing: 0) {
         VStack(spacing: 2) {
            Text("SUPER BOWL")
               .font(.system(size: 18, weight: .heavy))
               .foregroundColor(.gpGreen)

            Text("CHAMPION")
               .font(.system(size: 14, weight: .bold))
               .foregroundColor(.gpGreen)
         }
         .frame(height: headerHeight, alignment: .bottom)
         .padding(.bottom, 10)

         ZStack {
            Color.clear.frame(height: totalContentHeight)

            let afcChampGame = bracket.afcGames.filter { $0.round == .conference }.first
            let nfcChampGame = bracket.nfcGames.filter { $0.round == .conference }.first
            let afcWinner = afcChampGame != nil ? getWinner(from: afcChampGame!) : nil
            let nfcWinner = nfcChampGame != nil ? getWinner(from: nfcChampGame!) : nil
            let sbGame = bracket.superBowl

            // Only display an SB matchup if the ESPN SB event has real teams (not AFC/NFC placeholders).
            // If no real matchup, render neutral/empty cards (no logo, no solid team color), same as other empty cells.
            let sbDisplayGame: PlayoffGame? = {
               guard let sb = sbGame else { return nil }
               let homeAbbr = sb.homeTeam.abbreviation
               let awayAbbr = sb.awayTeam.abbreviation
               if isGenericTeam(homeAbbr) || isGenericTeam(awayAbbr) { return nil }
               return sb
            }()

            Group {
               // Center SB cards in the SB column (keeps the whole matchup centered visually)
               BracketTeamCell(team: sbDisplayGame?.awayTeam, game: sbDisplayGame, isReversed: false)
                  .position(x: (cellWidth + 30)/2, y: ySB_AFC + headerHeight - sbCardYOffset)
                  .scaleEffect(sbScale)

               if sbDisplayGame != nil {
                  Text("VS")
                     .font(.system(size: 14, weight: .black))
                     .padding()
                     .foregroundColor(.white.opacity(0.5))
                     .position(x: (cellWidth + 30)/2, y: ySB_Matchup_Center + headerHeight + 3)
               }

               BracketTeamCell(team: sbDisplayGame?.homeTeam, game: sbDisplayGame, isReversed: true)
                  .position(x: (cellWidth + 30)/2, y: ySB_NFC + headerHeight + sbCardYOffset)
                  .scaleEffect(sbScale)
            }
            .offset(y: -10)
            .contentShape(Rectangle())
            .onTapGesture {
               if let game = sbDisplayGame {
                  DebugPrint(mode: .nflData, "🎯 Tapped Super Bowl: \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
                  selectedGame = game
                  showingGameDetail = true
               }
            }
         }
         .offset(y: -23)
      }
      .frame(width: cellWidth + 30)
      .offset(y: -15)
   }

   @ViewBuilder
   private func matchupView(top: PlayoffTeam?, bot: PlayoffTeam?, isReversed: Bool, game: PlayoffGame? = nil) -> some View {
      VStack(spacing: matchupSpacing) {
         BracketTeamCell(team: top, game: game, isReversed: isReversed)
         BracketTeamCell(team: bot, game: game, isReversed: isReversed)
      }
      .contentShape(Rectangle())
      .onTapGesture {
         if let game = game {
            DebugPrint(mode: .nflData, "🎯 Tapped game: \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation) on \(game.gameDate)")
            selectedGame = game
            showingGameDetail = true
         }
      }
   }

   @ViewBuilder
   private func matchupView(game: PlayoffGame, isReversed: Bool) -> some View {
      VStack(spacing: matchupSpacing) {
         BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
         BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
      }
      .contentShape(Rectangle())
      .onTapGesture {
         DebugPrint(mode: .nflData, "🎯 Tapped game: \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation) on \(game.gameDate)")
         selectedGame = game
         showingGameDetail = true
      }
   }

   @ViewBuilder
   private func championshipMatchupView(game: PlayoffGame, topDivGame: PlayoffGame?, isReversed: Bool) -> some View {
      let topBracketWinnerAbbr = topDivGame != nil ? getWinner(from: topDivGame!)?.abbreviation : nil
      let isHomeFromTop = topBracketWinnerAbbr != nil && game.homeTeam.abbreviation == topBracketWinnerAbbr
      let isAwayFromTop = topBracketWinnerAbbr != nil && game.awayTeam.abbreviation == topBracketWinnerAbbr
      VStack(spacing: matchupSpacing) {
         if isHomeFromTop {
            BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
            BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
         }
         else if isAwayFromTop {
            BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
            BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
         }
         else {
            let homeS = game.homeTeam.seed ?? 999
            let awayS = game.awayTeam.seed ?? 999
            if homeS < awayS {
               BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
               BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
            } else {
               BracketTeamCell(team: game.awayTeam, game: game, isReversed: isReversed)
               BracketTeamCell(team: game.homeTeam, game: game, isReversed: isReversed)
            }
         }
      }
      .position(x: cellWidth/2, y: (yChamp_Top + yChamp_Bot) / 2 + headerHeight)
      .contentShape(Rectangle())
      .onTapGesture {
         DebugPrint(mode: .nflData, "🎯 Tapped championship game: \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
         selectedGame = game
         showingGameDetail = true
      }
   }

   private func getSeedsForConference(bracket: PlayoffBracket, conference: PlayoffGame.Conference) -> [Int: PlayoffTeam] {
      var seeds: [Int: PlayoffTeam] = [:]
      let games = (conference == .afc ? bracket.afcGames : bracket.nfcGames)
      games.forEach { game in
         if let awaySeed = game.awayTeam.seed {
            seeds[awaySeed] = PlayoffTeam(
               abbreviation: normalizeTeamCode(game.awayTeam.abbreviation),
               name: game.awayTeam.name,
               seed: awaySeed,
               score: game.awayTeam.score,
               logoURL: game.awayTeam.logoURL
            )
         }
         if let homeSeed = game.homeTeam.seed {
            seeds[homeSeed] = PlayoffTeam(
               abbreviation: normalizeTeamCode(game.homeTeam.abbreviation),
               name: game.homeTeam.name,
               seed: homeSeed,
               score: game.homeTeam.score,
               logoURL: game.homeTeam.logoURL
            )
         }
      }
      if let s1 = (conference == .afc ? bracket.afcSeed1 : bracket.nfcSeed1) {
         seeds[1] = PlayoffTeam(
            abbreviation: normalizeTeamCode(s1.abbreviation),
            name: s1.name,
            seed: s1.seed,
            score: s1.score,
            logoURL: s1.logoURL
         )
      }
      return seeds
   }

   private func sortDivisionalGames(_ games: [PlayoffGame]) -> (PlayoffGame?, PlayoffGame?) {
      var divGame1: PlayoffGame? = nil
      var divGame2: PlayoffGame? = nil
      for game in games {
         let homeS = game.homeTeam.seed ?? 0
         let awayS = game.awayTeam.seed ?? 0
         if homeS == 1 || awayS == 1 {
            divGame1 = game
         } else {
            divGame2 = game
         }
      }
      return (divGame1, divGame2)
   }

   private func findWildCardGame(_ games: [PlayoffGame], highSeed: Int, lowSeed: Int) -> PlayoffGame? {
      return games.first { game in
         let homeS = game.homeTeam.seed ?? 0
         let awayS = game.awayTeam.seed ?? 0
         return (homeS == highSeed && awayS == lowSeed) || (homeS == lowSeed && awayS == highSeed)
      }
   }

   private func normalizeTeamCode(_ code: String) -> String {
      return (code == "WASH" || code == "WSH") ? "WSH" : code
   }

   private func getWinner(from game: PlayoffGame) -> PlayoffTeam? {
      guard game.isCompleted else { return nil }
      return (game.homeTeam.score ?? 0 > game.awayTeam.score ?? 0)
      ? game.homeTeam
      : (game.awayTeam.score ?? 0 > game.homeTeam.score ?? 0)
      ? game.awayTeam
      : nil
   }

   private func isAFCTeam(_ abbr: String) -> Bool {
      return NFLTeam.team(for: abbr)?.conference == .afc
   }

   private func isGenericTeam(_ abbr: String) -> Bool {
      return abbr == "AFC" || abbr == "NFC" || abbr == "TBD" || abbr.isEmpty
   }

   private func debugSuperBowlGame(_ sb: PlayoffGame, selectedYear: String) {
//#if DEBUG
//      let modeShouldDebug = false
//      if modeShouldDebug {
         debugPrint("""
---- DEBUG PLAYOFF SUPER BOWL ----
year: \(selectedYear)
id: \(sb.id)
round: \(sb.round)
status: \(sb.status)
home: \(sb.homeTeam.abbreviation) (\(sb.homeTeam.name)), score: \(sb.homeTeam.score ?? -1)
away: \(sb.awayTeam.abbreviation) (\(sb.awayTeam.name)), score: \(sb.awayTeam.score ?? -1)
----------------------------------
""")
//      }
//#endif
   }
   
   private func detailRow(icon: String, title: String, value: String) -> some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: icon)
            .font(.title3)
            .foregroundStyle(.blue)
            .frame(width: 24)
         
         VStack(alignment: .leading, spacing: 4) {
            Text(title)
               .font(.subheadline)
               .foregroundStyle(.secondary)
            
            Text(value)
               .font(.body)
               .fontWeight(.medium)
         }
         
         Spacer()
      }
   }

   // MARK: - Matchup Card (Duplicate from GameDetailSheet)
   
   @ViewBuilder
   private func matchupCardView(game: PlayoffGame) -> some View {
      let awayColor = teamAssets.team(for: game.awayTeam.abbreviation)?.primaryColor ?? .blue
      let homeColor = teamAssets.team(for: game.homeTeam.abbreviation)?.primaryColor ?? .red
      
      HStack(spacing: 0) {
         // Away team logo (left side)
         ZStack(alignment: .bottomTrailing) {
            if let logo = teamAssets.logo(for: game.awayTeam.abbreviation) {
               logo
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .scaleEffect(1.5)
                  .frame(width: 90, height: 90)
                  .clipped()
            }
            
            // Seed badge
            if let seed = game.awayTeam.seed {
               Text("#\(seed)")
                  .font(.system(size: 12, weight: .black))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Capsule().fill(Color.black.opacity(0.85)))
                  .padding(6)
            }
         }
         .frame(width: 100, height: 100)
         
         Spacer()
         
         // Center: Game info
         VStack(spacing: 3) {
            // Day name (smart format)
            if !game.smartFormattedDate.isEmpty {
               Text(game.smartFormattedDate.uppercased())
                  .font(.system(size: 12, weight: .bold))
                  .foregroundColor(.white)
                  .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            // Date & Time
            Text(game.formattedTime)
               .font(.system(size: 16, weight: .black))
               .foregroundColor(.white)
               .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            
            // Stadium
            if let venue = game.venue, let venueName = venue.fullName {
               Text(venueName)
                  .font(.system(size: 11, weight: .semibold))
                  .foregroundColor(.white.opacity(0.9))
                  .lineLimit(1)
                  .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
               
               // City, State
               if let city = venue.city, let state = venue.state {
                  Text("\(city), \(state)")
                     .font(.system(size: 10, weight: .medium))
                     .foregroundColor(.white.opacity(0.8))
                     .lineLimit(1)
                     .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
               } else if let city = venue.city {
                  Text(city)
                     .font(.system(size: 10, weight: .medium))
                     .foregroundColor(.white.opacity(0.8))
                     .lineLimit(1)
                     .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
               }
            }
            
            // Network
            if let broadcasts = game.broadcasts, !broadcasts.isEmpty {
               HStack(spacing: 4) {
                  Image(systemName: "antenna.radiowaves.left.and.right")
                     .font(.system(size: 9, weight: .semibold))
                     .foregroundColor(.white.opacity(0.7))
                  
                  Text(broadcasts.joined(separator: ", "))
                     .font(.system(size: 10, weight: .semibold))
                     .foregroundColor(.white.opacity(0.7))
                     .lineLimit(1)
               }
               .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
         }
         .frame(maxWidth: .infinity)
         .padding(.vertical, 8)
         
         Spacer()
         
         // Home team logo (right side)
         ZStack(alignment: .bottomTrailing) {
            if let logo = teamAssets.logo(for: game.homeTeam.abbreviation) {
               logo
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .scaleEffect(1.5)
                  .frame(width: 90, height: 90)
                  .clipped()
            }
            
            // Seed badge
            if let seed = game.homeTeam.seed {
               Text("#\(seed)")
                  .font(.system(size: 12, weight: .black))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Capsule().fill(Color.black.opacity(0.85)))
                  .padding(6)
            }
         }
         .frame(width: 100, height: 100)
      }
      .frame(height: 100)
      .background(
         // GRADIENT from away team color to home team color - EXACTLY like week 1-18 cards
         Rectangle()
            .fill(
               LinearGradient(
                  colors: [
                     awayColor.opacity(0.7),
                     awayColor.opacity(0.5),
                     homeColor.opacity(0.5),
                     homeColor.opacity(0.7)
                  ],
                  startPoint: .leading,
                  endPoint: .trailing
               )
            )
      )
      .overlay(
         Rectangle()
            .stroke(
               LinearGradient(
                  colors: [awayColor, homeColor],
                  startPoint: .leading,
                  endPoint: .trailing
               ),
               lineWidth: 2
            )
      )
      .clipShape(Rectangle())
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.3), radius: 8)
   }
   
   @ViewBuilder
   private func oddsRow(odds: GameBettingOdds) -> some View {
      HStack(alignment: .top, spacing: 12) {
         Image(systemName: "dollarsign.circle.fill")
            .font(.title3)
            .foregroundStyle(.green)
            .frame(width: 24)
         
         VStack(alignment: .leading, spacing: 8) {
            Text("Odds")
               .font(.subheadline)
               .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
               // Spread
               if let spread = odds.spreadDisplay {
                  HStack(spacing: 6) {
                     Text("Spread:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                     Text(spread)
                        .font(.caption)
                        .fontWeight(.semibold)
                  }
               }
               
               // Total
               if let total = odds.totalDisplay {
                  HStack(spacing: 6) {
                     Text("Total:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                     Text(total)
                        .font(.caption)
                        .fontWeight(.semibold)
                  }
               }
               
               // Moneyline
               if let favTeam = odds.favoriteMoneylineTeamCode,
                  let favOdds = odds.favoriteMoneylineOdds {
                  HStack(spacing: 6) {
                     Text("Favorite:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                     Text("\(favTeam) \(favOdds)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                  }
               }
               
               // Sportsbook
               if let book = odds.sportsbookEnum {
                  HStack(spacing: 4) {
                     Text("via")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                     SportsbookBadge(book: book, size: 9)
                  }
               }
            }
         }
         
         Spacer()
      }
   }
}