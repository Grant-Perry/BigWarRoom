//
//  PlayoffConferenceSideView.swift
//  BigWarRoom
//
//  One side (AFC or NFC) of the playoff bracket
//

import SwiftUI

struct PlayoffConferenceSideView: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   
   let conference: PlayoffGame.Conference
   let bracket: PlayoffBracket
   let isReversed: Bool
   let isCurrentSeason: Bool
   
   // Layout constants
   let cellWidth: CGFloat
   let cellHeight: CGFloat
   let matchupSpacing: CGFloat
   let groupSpacing: CGFloat
   let connectorWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   
   // Y positions
   let yWC1: CGFloat
   let yWC2: CGFloat
   let yWC3: CGFloat
   let yDiv1Top: CGFloat
   let yDiv1Bot: CGFloat
   let yDiv1Center: CGFloat
   let yDiv2Top: CGFloat
   let yDiv2Bot: CGFloat
   let yDiv2Center: CGFloat
   let yChampTop: CGFloat
   let yChampBot: CGFloat
   let yChampCenter: CGFloat
   
   let onGameTap: (PlayoffGame) -> Void
   
   var body: some View {
      let seeds = getSeedsForConference()
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
      
      if remainingGames.count >= 1 {
         wcGame2 = remainingGames[0]
      }
      if remainingGames.count >= 2 {
         wcGame3 = remainingGames[1]
      }
      
      return HStack(alignment: .top, spacing: 0) {
         wildCardColumn(seeds: seeds, wcGame1: wcGame1, wcGame2: wcGame2, wcGame3: wcGame3)
         wildCardConnectorColumn(wcGame1: wcGame1, wcGame2: wcGame2, wcGame3: wcGame3)
         divisionalColumn(seed1: seed1, divGame1: divGame1, divGame2: divGame2)
         divisionalConnectorColumn(divGame1: divGame1, divGame2: divGame2)
         championshipColumn(champGame: champGame, divGame1: divGame1)
         championshipConnectorColumn(champGame: champGame)
      }
      .environment(\.layoutDirection, isReversed ? .rightToLeft : .leftToRight)
   }
   
   // MARK: - Column Views
   
   @ViewBuilder
   private func wildCardColumn(seeds: [Int: PlayoffTeam], wcGame1: PlayoffGame?, wcGame2: PlayoffGame?, wcGame3: PlayoffGame?) -> some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: cellWidth, height: totalContentHeight)
         
         // Conference logo
         if let confLogo = teamAssets.logo(for: (conference == .afc ? "AFC" : "NFC")) {
            confLogo
               .resizable()
               .aspectRatio(contentMode: .fit)
               .frame(width: 56, height: 56)
               .offset(x: conference == .afc ? 120 : 120, y: -headerHeight - 22)
         } else {
            Text(conference == .afc ? "AFC" : "NFC")
               .font(.custom("BebasNeue-Regular", size: 30))
               .foregroundColor(.white)
               .frame(height: headerHeight, alignment: .top)
               .offset(x: conference == .afc ? 125 : 125, y: -headerHeight - 4)
         }

         BracketHeader(text: "WILD CARD")

         // Wild Card games
         if let game = wcGame1 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC1 + headerHeight)
         } else if isCurrentSeason {
            PlayoffMatchupView(topTeam: seeds[5], bottomTeam: seeds[4], isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC1 + headerHeight)
         }

         if let game = wcGame2 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC2 + headerHeight)
         } else if isCurrentSeason {
            PlayoffMatchupView(topTeam: seeds[6], bottomTeam: seeds[3], isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC2 + headerHeight)
         }

         if let game = wcGame3 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC3 + headerHeight)
         } else if isCurrentSeason {
            PlayoffMatchupView(topTeam: seeds[7], bottomTeam: seeds[2], isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yWC3 + headerHeight)
         }
      }
      .frame(width: cellWidth)
   }
   
   @ViewBuilder
   private func wildCardConnectorColumn(wcGame1: PlayoffGame?, wcGame2: PlayoffGame?, wcGame3: PlayoffGame?) -> some View {
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
   
   @ViewBuilder
   private func divisionalColumn(seed1: PlayoffTeam?, divGame1: PlayoffGame?, divGame2: PlayoffGame?) -> some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: cellWidth, height: totalContentHeight)
         BracketHeader(text: "DIVISIONAL")
         
         // Divisional Game 1
         if let game = divGame1 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yDiv1Center + headerHeight)
         } else if isCurrentSeason {
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv1Top + headerHeight)
            BracketTeamCell(team: seed1, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv1Bot + headerHeight)
         }

         // Divisional Game 2
         if let game = divGame2 {
            PlayoffMatchupView(game: game, isReversed: isReversed, matchupSpacing: matchupSpacing, onTap: onGameTap)
               .position(x: cellWidth/2, y: yDiv2Center + headerHeight)
         } else if isCurrentSeason {
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv2Top + headerHeight)
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yDiv2Bot + headerHeight)
         }
      }
      .frame(width: cellWidth)
   }
   
   @ViewBuilder
   private func divisionalConnectorColumn(divGame1: PlayoffGame?, divGame2: PlayoffGame?) -> some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: connectorWidth, height: totalContentHeight)
         BracketHeader(text: "")
         Div_Champ_Connector(
            isReversed: isReversed,
            src1: divGame1 != nil ? yDiv1Center : nil,
            src2: divGame2 != nil ? yDiv2Center : nil,
            dst_top: yChampTop,
            dst_bot: yChampBot
         )
         .offset(y: headerHeight)
         .scaleEffect(x: isReversed ? -1 : 1, y: 1)
      }
      .frame(width: connectorWidth)
   }
   
   @ViewBuilder
   private func championshipColumn(champGame: PlayoffGame?, divGame1: PlayoffGame?) -> some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: cellWidth, height: totalContentHeight)
         BracketHeader(text: conference == .afc ? "AFC CHAMP" : "NFC CHAMP")

         if let game = champGame {
            PlayoffChampionshipMatchupView(
               game: game,
               topDivGame: divGame1,
               isReversed: isReversed,
               yChampTop: yChampTop,
               yChampBot: yChampBot,
               headerHeight: headerHeight,
               cellWidth: cellWidth,
               matchupSpacing: matchupSpacing,
               onTap: onGameTap
            )
         } else if isCurrentSeason {
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yChampTop + headerHeight)
            BracketTeamCell(team: nil, game: nil, isReversed: isReversed)
               .position(x: cellWidth/2, y: yChampBot + headerHeight)
         }
      }
      .frame(width: cellWidth)
   }
   
   @ViewBuilder
   private func championshipConnectorColumn(champGame: PlayoffGame?) -> some View {
      ZStack(alignment: .top) {
         Color.clear.frame(width: connectorWidth, height: totalContentHeight)
         BracketHeader(text: "")
         
         if conference == .afc {
            Champ_SB_Connector(
               isReversed: false,
               src: champGame != nil ? yChampCenter + headerHeight : nil,
               dst: yChampCenter + headerHeight - 23
            )
         } else {
            Champ_SB_Connector(
               isReversed: false,
               src: champGame != nil ? yChampCenter + headerHeight : nil,
               dst: yChampCenter + headerHeight - 23
            )
            .scaleEffect(x: -1, y: 1)
            .offset(y: 45)
         }
      }
      .frame(width: connectorWidth)
   }
   
   // MARK: - Helper Functions
   
   private func getSeedsForConference() -> [Int: PlayoffTeam] {
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
}