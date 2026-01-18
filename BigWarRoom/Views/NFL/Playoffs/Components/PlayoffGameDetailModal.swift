//
//  PlayoffGameDetailModal.swift
//  BigWarRoom
//
//  Modal displaying detailed playoff game information
//

import SwiftUI

struct PlayoffGameDetailModal: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    @AppStorage("selectedSportsbook") private var selectedBook: String = Sportsbook.fanduel.rawValue
    
    let game: PlayoffGame
    let playoffService: NFLPlayoffBracketService
    let onDismiss: () -> Void
    let onBookPickerTap: () -> Void
    let onLastPlayTap: (String) -> Void
    
    private let scoreSize: CGFloat = 80
    private let scoreOffset: CGFloat = 24
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            GeometryReader { geo in
                let screenWidth = geo.size.width
                let isProMax = screenWidth >= 900
                let modalScale: CGFloat = game.isLive ? (isProMax ? 0.75 : 0.65) : (isProMax ? 1.25 : 0.90)
                
                VStack(spacing: 0) {
                    headerView
                    
                    if game.isLive, let situation = game.liveSituation {
                        liveGameContent(situation: situation)
                    } else {
                        scheduledGameContent
                    }
                }
                .frame(width: 480)
                .scaleEffect(modalScale)
                .fixedSize(horizontal: false, vertical: true)
                .background(game.isLive ? Color(.systemBackground) : Color.clear)
                .cornerRadius(20)
                .shadow(color: game.isLive ? .white.opacity(0.3) : .clear, radius: 30, x: 0, y: 0)
                .shadow(color: game.isLive ? .black.opacity(0.5) : .clear, radius: 40, x: 0, y: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
    
    private var headerView: some View {
        HStack {
            Text(game.round.displayName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                onDismiss()
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
    }
    
    @ViewBuilder
    private func liveGameContent(situation: LiveGameSituation) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                matchupCard
                
                PlayoffLiveGameSituationCard(
                    situation: situation,
                    game: game,
                    onLastPlayTap: onLastPlayTap
                )
                .padding(.horizontal, 16)
                
                if displayOdds != nil {
                    oddsBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
            }
        }
    }
    
    @ViewBuilder
    private var scheduledGameContent: some View {
        matchupCard
            .scaleEffect(1.1)
            .shadow(color: .white.opacity(0.3), radius: 30, x: 0, y: 0)
            .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 10)
            .padding(.top, 8)
            .padding(.bottom, 12)
        
        if !game.isCompleted, gameOdds != nil {
            oddsBar
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }
    
    private var matchupCard: some View {
        PlayoffGameDetailCard(
            game: game,
            displayOdds: displayOdds,
            scoreSize: scoreSize,
            scoreOffset: scoreOffset
        )
        .padding(.top, 4)
    }
    
    private var oddsBar: some View {
        PlayoffOddsBar(
            displayOdds: displayOdds,
            currentSportsbook: Sportsbook(rawValue: selectedBook) ?? .fanduel,
            onBookPickerTap: onBookPickerTap
        )
    }
    
    private var gameOdds: GameBettingOdds? {
        let gameID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
        return playoffService.gameOdds[gameID]
    }
    
    private var displayOdds: GameBettingOdds? {
        let currentSportsbook = Sportsbook(rawValue: selectedBook) ?? .fanduel
        return BettingOddsHelpers.getDisplayOdds(from: gameOdds, book: currentSportsbook)
    }
}