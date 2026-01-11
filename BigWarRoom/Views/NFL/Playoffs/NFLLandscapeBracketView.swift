//
//   NFLLandscapeBracketView.swift
//   BigWarRoom
//

import SwiftUI

struct NFLLandscapeBracketView: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   @Environment(NFLStandingsService.self) private var standingsService
   let playoffService: NFLPlayoffBracketService

   // 🔥 NEW: Computed property to get current bracket
   private var bracket: PlayoffBracket? {
      let bracket = playoffService.currentBracket
      
      // 🔥 NEW: Log when bracket property is accessed
      if let b = bracket {
         let liveCount = b.afcGames.filter { $0.isLive }.count + b.nfcGames.filter { $0.isLive }.count
         DebugPrint(mode: .bracketTimer, "🔍 [LANDSCAPE VIEW] Bracket accessed - Live games: \(liveCount)")
      }
      
      return bracket
   }

   @State private var yearManager = SeasonYearManager.shared
   @State private var selectedGameID: String?
   @State private var showingGameDetail = false
   @State private var showingBookPicker = false
   @State private var showLastPlayDetail = false
   @State private var lastPlayText: String = ""
   @AppStorage("selectedSportsbook") private var selectedBook: String = Sportsbook.fanduel.rawValue
   
   // Smart connector points
   @State private var afcChampPoint: ConnectionPoint?
   @State private var nfcChampPoint: ConnectionPoint?
   @State private var afcSBPoint: ConnectionPoint?
   @State private var nfcSBPoint: ConnectionPoint?

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
         if let bracket = bracket {
            bracketContent(bracket: bracket, geo: geo)
         } else {
            loadingView
         }
      }
      .overlay {
         // Last Play detail popup
         if showLastPlayDetail {
            lastPlayDetailOverlay
         }
      }
   }
   
   @ViewBuilder
   private func bracketContent(bracket: PlayoffBracket, geo: GeometryProxy) -> some View {
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
      let contentScale = isLargeScreen ? 1.1 : 1.0

      ZStack {
         Image("BG3")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.25)
            .ignoresSafeArea()

         VStack(spacing: 0) {
            yearPickerMenu(headerFontSize: headerFontSize, topPadding: topPadding, bottomPadding: bottomPadding)

            HStack(alignment: .top, spacing: 0) {
               conferenceSide(conference: .afc, isReversed: false, bracket: bracket)
               superBowlColumn(bracket: bracket)
               conferenceSide(conference: .nfc, isReversed: true, bracket: bracket)
            }
            .onPreferenceChange(AFCChampConnectionKey.self) { point in
               afcChampPoint = point
            }
            .onPreferenceChange(NFCChampConnectionKey.self) { point in
               nfcChampPoint = point
            }
            .onPreferenceChange(AFCSBConnectionKey.self) { point in
               afcSBPoint = point
            }
            .onPreferenceChange(NFCSBConnectionKey.self) { point in
               nfcSBPoint = point
            }
            .background(
               GeometryReader { geo in
                  ZStack {
                     // Draw smart connectors using the geometry
                     if let start = afcChampPoint, let end = afcSBPoint {
                        SmartBracketConnector(startPoint: start, endPoint: end, isReversed: false)
                     }
                     if let start = nfcChampPoint, let end = nfcSBPoint {
                        SmartBracketConnector(startPoint: start, endPoint: end, isReversed: true)
                     }
                  }
                  .coordinateSpace(name: "bracket")
               }
            )
            .scaleEffect(contentScale)
            .scaleEffect(finalScale)
            .frame(width: idealTotalWidth * finalScale, height: (totalContentHeight + headerHeight + 50) * finalScale)
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         
         // Game detail modal overlay
         if showingGameDetail, let gameID = selectedGameID, let game = findGame(by: gameID, in: bracket) {
            gameDetailOverlay(game: game)
         }
         
         // Book picker modal overlay
         if showingBookPicker, let gameID = selectedGameID, let game = findGame(by: gameID, in: bracket) {
            bookPickerOverlay(game: game)
         }
      }
   }
   
   @ViewBuilder
   private var loadingView: some View {
      ZStack {
         Color.black.ignoresSafeArea()
         VStack(spacing: 16) {
            ProgressView()
               .scaleEffect(1.5)
               .tint(.white)
            Text("Loading bracket...")
               .foregroundColor(.white)
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
   private func conferenceSide(conference: PlayoffGame.Conference, isReversed: Bool, bracket: PlayoffBracket) -> some View {
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
   
   private func superBowlColumn(bracket: PlayoffBracket) -> some View {
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
               selectedGameID = nil
            }
         
         GeometryReader { geo in
            let screenWidth = geo.size.width
            // iPhone Pro Max in landscape ~930pts, standard iPhones ~850pts
            let isProMax = screenWidth >= 900
            let modalScale = isProMax ? 0.85 : 0.75

            VStack(spacing: 0) {
               // Header with timer - SUPER COMPACT
               HStack {
                  Text(game.round.displayName)
                     .font(.headline)
                     .fontWeight(.bold)
                     .foregroundStyle(.white)
                  
                  Spacer()
                  
                  // 🏈 NEW: Refresh countdown timer (only for live games)
                  if game.isLive {
                     RefreshCountdownTimerView()
                  }
                  
                  Spacer()
                  
                  Button {
                     showingGameDetail = false
                     selectedGameID = nil
                  } label: {
                     Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                  }
               }
               .padding(.horizontal, 16)
               .padding(.vertical, 6)
               .frame(height: 36)
               .background(Color(.systemGray6))
               
               // 🏈 NEW: Live game situation (if game is live)
               if game.isLive, let situation = game.liveSituation {
                  ScrollView {
                     VStack(spacing: 10) {
                        // Matchup Card
                        let gameID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
                        let odds = playoffService.gameOdds[gameID]
                        let currentSportsbook = Sportsbook(rawValue: selectedBook) ?? .fanduel
                        let displayOdds = getDisplayOdds(from: odds, book: currentSportsbook)
                        
                        // DEBUG: Log odds availability
                        let _ = {
                           DebugPrint(mode: .bettingOdds, "🎰 [MODAL ODDS] Game: \(gameID), Has odds: \(odds != nil), DisplayOdds: \(displayOdds != nil)")
                           if odds == nil {
                              DebugPrint(mode: .bettingOdds, "⚠️ [MODAL] No odds in gameOdds dict for \(gameID)")
                              DebugPrint(mode: .bettingOdds, "🔍 [MODAL] Available odds keys: \(playoffService.gameOdds.keys.sorted().joined(separator: ", "))")
                           }
                        }()
                        
                        PlayoffGameDetailCard(
                           game: game,
                           displayOdds: displayOdds,
                           scoreSize: scoreSize,
                           scoreOffset: scoreOffset
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        
                        // Live situation card
                        liveGameSituationView(situation: situation, game: game)
                           .padding(.horizontal, 16)
                        
                        // Odds bar for live games
                        if displayOdds != nil {
                           PlayoffOddsBar(
                              displayOdds: displayOdds,
                              currentSportsbook: currentSportsbook,
                              onBookPickerTap: { showingBookPicker = true }
                           )
                           .padding(.horizontal, 16)
                           .padding(.bottom, 10)
                        }
                     }
                  }
               } else {
                  // Matchup Card (non-live games)
                  let gameID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
                  let odds = playoffService.gameOdds[gameID]
                  let currentSportsbook = Sportsbook(rawValue: selectedBook) ?? .fanduel
                  let displayOdds = getDisplayOdds(from: odds, book: currentSportsbook)
                  
                  PlayoffGameDetailCard(
                     game: game,
                     displayOdds: displayOdds,
                     scoreSize: scoreSize,
                     scoreOffset: scoreOffset
                  )
                  .padding(.horizontal, 16)
                  .padding(.top, 8)
                  .padding(.bottom, 12)
                  
                  // Odds bar (only if game not completed)
                  if !game.isCompleted, odds != nil {
                     PlayoffOddsBar(
                        displayOdds: displayOdds,
                        currentSportsbook: currentSportsbook,
                        onBookPickerTap: { showingBookPicker = true }
                     )
                     .padding(.horizontal, 16)
                     .padding(.bottom, 12)
                  }
               }
            }
            .frame(width: 480)
            .scaleEffect(modalScale)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .white.opacity(0.3), radius: 30, x: 0, y: 0)
            .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
         }
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: showingGameDetail)
   }
   
   // 🏈 NEW: Live game situation display
   @ViewBuilder
   private func liveGameSituationView(situation: LiveGameSituation, game: PlayoffGame) -> some View {
      VStack(alignment: .leading, spacing: 12) {
         // Header
         HStack(spacing: 12) {
            Image(systemName: "sportscourt.fill")
               .font(.title3)
               .foregroundStyle(.red)
               .frame(width: 24)
            
            Text("Live Game Situation")
               .font(.subheadline)
               .fontWeight(.semibold)
               .foregroundStyle(.primary)
            
            Spacer()
         }
         
         // 🔥 NEW: Last Play (left) and Current Drive (right) in same row
         HStack(alignment: .top, spacing: 12) {
            // Last Play - tappable for full text
            if let lastPlay = situation.lastPlay {
               Button {
                  showLastPlayDetail = true
                  lastPlayText = lastPlay
               } label: {
                  VStack(alignment: .leading, spacing: 6) {
                     Text("Last Play")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                     
                     Text(lastPlay)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(Color(.tertiarySystemGroupedBackground))
                  .cornerRadius(8)
                  .contentShape(Rectangle())
               }
               .buttonStyle(.plain)
            }
            
            // Current Drive Stats
            if situation.drivePlayCount != nil || situation.driveYards != nil || situation.timeOfPossession != nil {
               VStack(alignment: .leading, spacing: 6) {
                  Text("Current Drive")
                     .font(.caption)
                     .foregroundStyle(.secondary)
                  
                  HStack(spacing: 12) {
                     if let yards = situation.driveYards {
                        VStack(alignment: .leading, spacing: 2) {
                           Text("\(yards)")
                              .font(.title3)
                              .fontWeight(.bold)
                           Text("Yards")
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                        }
                     }
                     
                     if let top = situation.timeOfPossession {
                        VStack(alignment: .leading, spacing: 2) {
                           Text(top)
                              .font(.title3)
                              .fontWeight(.bold)
                           Text("TOP")
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                        }
                     }
                  }
               }
               .padding(.horizontal, 12)
               .padding(.vertical, 8)
               .frame(maxWidth: .infinity, alignment: .leading)
               .background(Color(.tertiarySystemGroupedBackground))
               .cornerRadius(8)
            }
         }
         
         // Down & Distance with Field Position - ONLY show if down/distance are valid
         if let down = situation.down,
            let distance = situation.distance,
            down > 0, down <= 4, distance >= 0 {
            HStack(spacing: 8) {
               VStack(alignment: .leading, spacing: 2) {
                  Text("Down & Distance")
                     .font(.caption)
                     .foregroundStyle(.secondary)
                  
                  let suffix: String = {
                     switch down {
                     case 1: return "st"
                     case 2: return "nd"
                     case 3: return "rd"
                     default: return "th"
                     }
                  }()
                  
                  // Extract quarter and time from game status
                  let clockInfo: String = {
                     if case .inProgress(let quarter, let time) = game.status {
                        return "\(quarter) \(time)"
                     }
                     return ""
                  }()
                  
                  HStack(spacing: 10) {
                     Text("\(down)\(suffix) & \(distance)")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundStyle(.primary)
                     
                     if !clockInfo.isEmpty {
                        Text("(\(clockInfo))")
                           .font(.callout)
                           .fontWeight(.semibold)
                           .foregroundStyle(.secondary)
                     }
                  }
               }
               
               Spacer()
               
               // Field position
               if let yardLine = situation.yardLine {
                  VStack(alignment: .trailing, spacing: 2) {
                     Text("Field Position")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                     
                     Text(yardLine)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                  }
               }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)
         }
      }
      .padding()
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(12)
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
         if let odds = playoffService.gameOdds[gameID] {
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
   
   @ViewBuilder
   private var lastPlayDetailOverlay: some View {
      ZStack {
         Color.black.opacity(0.75)
            .ignoresSafeArea()
            .onTapGesture {
               showLastPlayDetail = false
            }
         
         VStack(spacing: 8) {
            // Compact header
            HStack {
               Text("Last Play")
                  .font(.caption)
                  .fontWeight(.bold)
                  .foregroundStyle(.white)
               
               Spacer()
               
               Button {
                  showLastPlayDetail = false
               } label: {
                  Image(systemName: "xmark.circle.fill")
                     .font(.caption)
                     .foregroundStyle(.white.opacity(0.7))
               }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            
            // Compact play text
            Text(lastPlayText)
               .font(.caption2)
               .foregroundStyle(.primary)
               .padding(12)
               .frame(maxWidth: .infinity, alignment: .leading)
         }
         .frame(width: 280)
         .fixedSize(horizontal: false, vertical: true)
         .background(Color(.systemBackground))
         .cornerRadius(12)
         .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 5)
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: showLastPlayDetail)
   }
   
   // MARK: - Helpers
   
   private func handleGameTap(_ game: PlayoffGame) {
      selectedGameID = game.id
      showingGameDetail = true
   }
   
   // 🔥 NEW: Find current game by ID in provided bracket
   private func findGame(by id: String, in bracket: PlayoffBracket) -> PlayoffGame? {
      // Search all games in current bracket
      let allGames = bracket.afcGames + bracket.nfcGames + (bracket.superBowl != nil ? [bracket.superBowl!] : [])
      let game = allGames.first { $0.id == id }
      
      // 🔥 NEW: Log game lookup
      if let g = game {
         DebugPrint(mode: .bracketTimer, "🔍 [GAME LOOKUP] Found game \(id): \(g.awayTeam.abbreviation)@\(g.homeTeam.abbreviation), Status: \(g.status.displayText), Away: \(g.awayTeam.score ?? 0), Home: \(g.homeTeam.score ?? 0)")
      } else {
         DebugPrint(mode: .bracketTimer, "⚠️ [GAME LOOKUP] Could not find game \(id) in bracket!")
      }
      
      return game
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