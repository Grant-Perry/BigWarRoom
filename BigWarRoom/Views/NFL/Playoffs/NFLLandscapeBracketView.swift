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
   @State private var showingBookPicker = false
   @AppStorage("selectedSportsbook") private var selectedBook: String = Sportsbook.fanduel.rawValue

   private let cellWidth: CGFloat = 95
   private let cellHeight: CGFloat = 40
   private let matchupSpacing: CGFloat = 6
   private let groupSpacing: CGFloat = 20
   private let connectorWidth: CGFloat = 30
   private let headerHeight: CGFloat = 26
   private let sbCardYOffset: CGFloat = 10
   private let sbGroupYOffset: CGFloat = -10
   private let sbScale: CGFloat = 1.15
   private let scoreSize: CGFloat = 80
   private let scoreOffset: CGFloat = 24
   
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
         let widthScale = (availableWidth - 40) / idealTotalWidth
         let heightScale = (availableHeight - 180) / (totalContentHeight + headerHeight + 50)
         let finalScale = min(widthScale, heightScale, 1.0)
         let headerFontSize: CGFloat = availableWidth < 700 ? 24 : 32
         let topPadding: CGFloat = availableWidth < 700 ? 20 : 45
         let bottomPadding: CGFloat = availableWidth < 700 ? 10 : 20
         
         // Determine if we should apply the 1.1 scale boost based on screen size
         // iPhone Pro Max/Plus in landscape ~930pts, standard iPhones ~850pts
         let isLargeScreen = availableWidth >= 900
         let contentScale = isLargeScreen ? 1.2 : 1.0

         ZStack {
            Image("BG3")
               .resizable()
               .aspectRatio(contentMode: .fill)
               .opacity(0.25)
               .ignoresSafeArea()

            VStack(spacing: 0) {
               yearPickerMenu(headerFontSize: headerFontSize, topPadding: topPadding, bottomPadding: bottomPadding)

               HStack(alignment: .top, spacing: 0) {
                  conferenceSide(conference: .afc, isReversed: false)
                  superBowlColumn
                  conferenceSide(conference: .nfc, isReversed: true)
               }
               .scaleEffect(contentScale)
               .scaleEffect(finalScale)
               .frame(width: idealTotalWidth * finalScale, height: (totalContentHeight + headerHeight + 50) * finalScale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
         }
         
         // Game detail modal overlay
         if showingGameDetail, let game = selectedGame {
            gameDetailOverlay(game: game)
         }
         
         // Book picker modal overlay
         if showingBookPicker, let game = selectedGame {
            bookPickerOverlay(game: game)
         }
      }
   }

   // MARK: - Subviews
   
   @ViewBuilder
   private func yearPickerMenu(headerFontSize: CGFloat, topPadding: CGFloat, bottomPadding: CGFloat) -> some View {
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
   }
   
   @ViewBuilder
   private func conferenceSide(conference: PlayoffGame.Conference, isReversed: Bool) -> some View {
      let actualCurrentSeasonYear = NFLWeekCalculator.getCurrentSeasonYear()
      let isCurrentSeason = (bracket.season == actualCurrentSeasonYear)
      
      PlayoffConferenceSideView(
         conference: conference,
         bracket: bracket,
         isReversed: isReversed,
         isCurrentSeason: isCurrentSeason,
         cellWidth: cellWidth,
         cellHeight: cellHeight,
         matchupSpacing: matchupSpacing,
         groupSpacing: groupSpacing,
         connectorWidth: connectorWidth,
         headerHeight: headerHeight,
         totalContentHeight: totalContentHeight,
         yWC1: yWC1,
         yWC2: yWC2,
         yWC3: yWC3,
         yDiv1Top: yDiv1_Top,
         yDiv1Bot: yDiv1_Bot,
         yDiv1Center: yDiv1_Center,
         yDiv2Top: yDiv2_Top,
         yDiv2Bot: yDiv2_Bot,
         yDiv2Center: yDiv2_Center,
         yChampTop: yChamp_Top,
         yChampBot: yChamp_Bot,
         yChampCenter: yChamp_Center,
         onGameTap: handleGameTap
      )
   }
   
   private var superBowlColumn: some View {
      PlayoffSuperBowlColumnView(
         bracket: bracket,
         cellWidth: cellWidth,
         headerHeight: headerHeight,
         totalContentHeight: totalContentHeight,
         ySBMatchupCenter: ySB_Matchup_Center,
         ySBAFC: ySB_AFC,
         ySBNFC: ySB_NFC,
         sbCardYOffset: sbCardYOffset,
         sbScale: sbScale,
         onTap: handleGameTap
      )
   }
   
   @ViewBuilder
   private func gameDetailOverlay(game: PlayoffGame) -> some View {
      ZStack {
         Color.black.opacity(0.75)
            .ignoresSafeArea()
            .onTapGesture {
               showingGameDetail = false
               selectedGame = nil
            }
         
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
            
            // Matchup Card
            let gameID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
            let odds = playoffService?.gameOdds[gameID]
            let currentSportsbook = Sportsbook(rawValue: selectedBook) ?? .fanduel
            let displayOdds = getDisplayOdds(from: odds, book: currentSportsbook)
            
            PlayoffGameDetailCard(
               game: game,
               displayOdds: displayOdds,
               scoreSize: scoreSize,
               scoreOffset: scoreOffset
            )
            .padding()
            
            // Odds bar (only if game not completed)
            if !game.isCompleted, odds != nil {
               PlayoffOddsBar(
                  displayOdds: displayOdds,
                  currentSportsbook: currentSportsbook,
                  onBookPickerTap: { showingBookPicker = true }
               )
               .padding(.horizontal)
               .padding(.bottom, 16)
            }
         }
         .frame(width: 500)
         .fixedSize(horizontal: false, vertical: true)
         .background(Color(.systemBackground))
         .cornerRadius(20)
         .shadow(color: .white.opacity(0.3), radius: 30, x: 0, y: 0)
         .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 10)
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: showingGameDetail)
   }
   
   @ViewBuilder
   private func bookPickerOverlay(game: PlayoffGame) -> some View {
      ZStack {
         Color.black.opacity(0.75)
            .ignoresSafeArea()
            .onTapGesture {
               showingBookPicker = false
            }
         
         let gameID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
         if let odds = playoffService?.gameOdds[gameID] {
            BookPickerSheet(
               odds: odds,
               selectedBook: $selectedBook,
               onDismiss: { showingBookPicker = false }
            )
            .shadow(color: .black.opacity(0.3), radius: 20)
         }
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: showingBookPicker)
   }
   
   // MARK: - Helpers
   
   private func handleGameTap(_ game: PlayoffGame) {
      selectedGame = game
      showingGameDetail = true
   }
   
   private func getDisplayOdds(from odds: GameBettingOdds?, book: Sportsbook) -> GameBettingOdds? {
      guard let odds = odds else { return nil }
      
      if book == .bestLine {
         return odds
      }
      
      guard let bookOdds = odds.odds(for: book) else {
         return odds
      }
      
      return GameBettingOdds(
         gameID: odds.gameID,
         homeTeamCode: odds.homeTeamCode,
         awayTeamCode: odds.awayTeamCode,
         spreadDisplay: bookOdds.spreadPoints != nil ? "\(bookOdds.spreadTeamCode ?? "") \(bookOdds.spreadPoints! > 0 ? "+" : "")\(bookOdds.spreadPoints!)" : nil,
         totalDisplay: bookOdds.totalPoints != nil ? "O/U \(bookOdds.totalPoints!)" : nil,
         favoriteMoneylineTeamCode: bookOdds.favoriteTeamCode,
         favoriteMoneylineOdds: bookOdds.favoriteMoneylineDisplay,
         underdogMoneylineTeamCode: bookOdds.underdogTeamCode,
         underdogMoneylineOdds: bookOdds.underdogMoneylineDisplay,
         totalPoints: bookOdds.totalPoints != nil ? String(bookOdds.totalPoints!) : nil,
         moneylineDisplay: nil,
         sportsbook: book.displayName,
         sportsbookEnum: book,
         lastUpdated: odds.lastUpdated,
         allBookOdds: odds.allBookOdds
      )
   }
}
