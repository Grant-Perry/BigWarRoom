//
//  PlayoffSuperBowlColumnView.swift
//  BigWarRoom
//
//  Super Bowl column in playoff bracket
//

import SwiftUI

struct PlayoffSuperBowlColumnView: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   
   let bracket: PlayoffBracket
   let cellWidth: CGFloat
   let headerHeight: CGFloat
   let totalContentHeight: CGFloat
   let ySBMatchupCenter: CGFloat
   let ySBAFC: CGFloat
   let ySBNFC: CGFloat
   let sbCardYOffset: CGFloat
   let sbScale: CGFloat
   let onTap: (PlayoffGame) -> Void
   
   var body: some View {
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

            let sbDisplayGame = getSuperBowlDisplayGame()

            Group {
               // Center SB cards in the SB column
               BracketTeamCell(team: sbDisplayGame?.awayTeam, game: sbDisplayGame, isReversed: false)
                  .position(x: (cellWidth + 30)/2, y: ySBAFC + headerHeight - sbCardYOffset)
                  .scaleEffect(sbScale)

               if sbDisplayGame != nil {
                  Text("VS")
                     .font(.system(size: 14, weight: .black))
                     .padding()
                     .foregroundColor(.white.opacity(0.5))
                     .position(x: (cellWidth + 30)/2, y: ySBMatchupCenter + headerHeight + 3)
               }

               BracketTeamCell(team: sbDisplayGame?.homeTeam, game: sbDisplayGame, isReversed: true)
                  .position(x: (cellWidth + 30)/2, y: ySBNFC + headerHeight + sbCardYOffset)
                  .scaleEffect(sbScale)
            }
            .offset(y: -10)
            .contentShape(Rectangle())
            .onTapGesture {
               if let game = sbDisplayGame {
                  DebugPrint(mode: .nflData, "🎯 Tapped Super Bowl: \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
                  onTap(game)
               }
            }
         }
         .offset(y: -23)
      }
      .frame(width: cellWidth + 30)
      .offset(y: -15)
   }
   
   private func getSuperBowlDisplayGame() -> PlayoffGame? {
      guard let sb = bracket.superBowl else { return nil }
      let homeAbbr = sb.homeTeam.abbreviation
      let awayAbbr = sb.awayTeam.abbreviation
      if isGenericTeam(homeAbbr) || isGenericTeam(awayAbbr) { return nil }
      return sb
   }
   
   private func isGenericTeam(_ abbr: String) -> Bool {
      return abbr == "AFC" || abbr == "NFC" || abbr == "TBD" || abbr.isEmpty
   }
}