//
//   NFLLandscapeBracketView.swift
//   BigWarRoom
//

import SwiftUI

struct NFLLandscapeBracketView: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    @Environment(NFLStandingsService.self) private var standingsService
    
    let playoffService: NFLPlayoffBracketService
    
    @State private var yearManager = SeasonYearManager.shared
    @State private var selectedGameID: String?
    @State private var showingGameDetail = false
    @State private var showingBookPicker = false
    @State private var showLastPlayDetail = false
    @State private var lastPlayText: String = ""
    @AppStorage("selectedSportsbook") private var selectedBook: String = Sportsbook.fanduel.rawValue
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
    
    private var bracket: PlayoffBracket? {
        let bracket = playoffService.currentBracket
        
        if let b = bracket {
            let liveCount = b.afcGames.filter { $0.isLive }.count + b.nfcGames.filter { $0.isLive }.count
            DebugPrint(mode: .bracketTimer, "🔍 [LANDSCAPE VIEW] Bracket accessed - Live games: \(liveCount)")
        }
        
        return bracket
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
            if let bracket = bracket {
                bracketContent(bracket: bracket, geo: geo)
            } else {
                loadingView
            }
        }
        .overlay {
            if showLastPlayDetail {
                PlayoffLastPlayDetailModal(
                    lastPlayText: lastPlayText,
                    onDismiss: { showLastPlayDetail = false }
                )
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
        let isLargeScreen = availableWidth >= 900
        let contentScale = isLargeScreen ? 1.1 : 1.0
        
        ZStack {
            Image("BG3")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                PlayoffYearPickerMenu(
                    headerFontSize: headerFontSize,
                    topPadding: topPadding,
                    bottomPadding: bottomPadding
                )
                
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
            
            if showingGameDetail, let gameID = selectedGameID, let game = PlayoffGameHelpers.findGame(by: gameID, in: bracket) {
                PlayoffGameDetailModal(
                    game: game,
                    playoffService: playoffService,
                    onDismiss: {
                        showingGameDetail = false
                        selectedGameID = nil
                    },
                    onBookPickerTap: { showingBookPicker = true },
                    onLastPlayTap: { text in
                        lastPlayText = text
                        showLastPlayDetail = true
                    }
                )
            }
            
            if showingBookPicker, let gameID = selectedGameID, let game = PlayoffGameHelpers.findGame(by: gameID, in: bracket) {
                let gameOddsID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
                if let odds = playoffService.gameOdds[gameOddsID] {
                    PlayoffBookPickerModal(
                        odds: odds,
                        selectedBook: $selectedBook,
                        onDismiss: { showingBookPicker = false }
                    )
                }
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
    
    private func handleGameTap(_ game: PlayoffGame) {
        selectedGameID = game.id
        showingGameDetail = true
    }
}