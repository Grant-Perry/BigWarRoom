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
         WildCardColumnView(
            conference: conference,
            seeds: seeds,
            wcGame1: wcGame1,
            wcGame2: wcGame2,
            wcGame3: wcGame3,
            isReversed: isReversed,
            isCurrentSeason: isCurrentSeason,
            cellWidth: cellWidth,
            headerHeight: headerHeight,
            totalContentHeight: totalContentHeight,
            yWC1: yWC1,
            yWC2: yWC2,
            yWC3: yWC3,
            matchupSpacing: matchupSpacing,
            onGameTap: onGameTap
         )
         
         WildCardConnectorColumnView(
            wcGame1: wcGame1,
            wcGame2: wcGame2,
            wcGame3: wcGame3,
            isReversed: isReversed,
            isCurrentSeason: isCurrentSeason,
            connectorWidth: connectorWidth,
            headerHeight: headerHeight,
            totalContentHeight: totalContentHeight,
            yWC1: yWC1,
            yWC2: yWC2,
            yWC3: yWC3,
            yDiv1Top: yDiv1Top,
            yDiv2Top: yDiv2Top,
            yDiv2Bot: yDiv2Bot
         )
         
         DivisionalColumnView(
            seed1: seed1,
            divGame1: divGame1,
            divGame2: divGame2,
            isReversed: isReversed,
            isCurrentSeason: isCurrentSeason,
            cellWidth: cellWidth,
            headerHeight: headerHeight,
            totalContentHeight: totalContentHeight,
            yDiv1Top: yDiv1Top,
            yDiv1Bot: yDiv1Bot,
            yDiv1Center: yDiv1Center,
            yDiv2Top: yDiv2Top,
            yDiv2Bot: yDiv2Bot,
            yDiv2Center: yDiv2Center,
            matchupSpacing: matchupSpacing,
            onGameTap: onGameTap
         )
         
         DivisionalConnectorColumnView(
            divGame1: divGame1,
            divGame2: divGame2,
            isReversed: isReversed,
            isCurrentSeason: isCurrentSeason,
            connectorWidth: connectorWidth,
            headerHeight: headerHeight,
            totalContentHeight: totalContentHeight,
            yDiv1Center: yDiv1Center,
            yDiv2Center: yDiv2Center,
            yChampTop: yChampTop,
            yChampBot: yChampBot
         )
         
         ChampionshipColumnView(
            conference: conference,
            champGame: champGame,
            divGame1: divGame1,
            isReversed: isReversed,
            isCurrentSeason: isCurrentSeason,
            cellWidth: cellWidth,
            headerHeight: headerHeight,
            totalContentHeight: totalContentHeight,
            yChampTop: yChampTop,
            yChampBot: yChampBot,
            yChampCenter: yChampCenter,
            matchupSpacing: matchupSpacing,
            onGameTap: onGameTap
         )
         
         ChampionshipConnectorColumnView(
            conference: conference,
            champGame: champGame,
            isReversed: isReversed,
            isCurrentSeason: isCurrentSeason,
            connectorWidth: connectorWidth,
            headerHeight: headerHeight,
            totalContentHeight: totalContentHeight,
            yChampCenter: yChampCenter
         )
      }
      .environment(\.layoutDirection, isReversed ? .rightToLeft : .leftToRight)
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