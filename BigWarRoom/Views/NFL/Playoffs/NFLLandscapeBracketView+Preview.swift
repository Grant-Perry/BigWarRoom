//
//  NFLLandscapeBracketView+Preview.swift
//  BigWarRoom
//
//  Preview provider for NFLLandscapeBracketView
//

import SwiftUI

#Preview("Wild Card Live Game Popup") {
    let mockLiveGame = PlayoffGame(
        id: "mock-wc-1",
        round: .wildCard,
        conference: .afc,
        homeTeam: PlayoffTeam(
            abbreviation: "PIT",
            name: "Pittsburgh Steelers",
            seed: 4,
            score: 3,
            logoURL: nil,
            timeoutsRemaining: 2
        ),
        awayTeam: PlayoffTeam(
            abbreviation: "HOU",
            name: "Houston Texans",
            seed: 5,
            score: 0,
            logoURL: nil,
            timeoutsRemaining: 3
        ),
        gameDate: Date(),
        status: .inProgress(quarter: "Q1", timeRemaining: "5:58"),
        venue: PlayoffGame.Venue(
            fullName: "Acrisure Stadium",
            city: "Pittsburgh",
            state: "PA"
        ),
        broadcasts: ["ABC", "ESPN+"],
        liveSituation: LiveGameSituation(
            down: 2,
            distance: 6,
            yardLine: "HOU 30",
            possession: "HOU",
            lastPlay: "(Shotgun) C.Stroud pass short middle to N.Collins to HST 30 for 4 yards (J.Porter).",
            drivePlayCount: nil,
            driveYards: 4,
            timeOfPossession: "0:04",
            homeTimeouts: 2,
            awayTimeouts: 3
        ),
        lastKnownDownDistance: nil
    )
    
    let mockOdds = GameBettingOdds(
        gameID: "HOU@PIT",
        homeTeamCode: "PIT",
        awayTeamCode: "HOU",
        spreadDisplay: "PIT -1.5",
        totalDisplay: "O/U 36.5",
        favoriteMoneylineTeamCode: "PIT",
        favoriteMoneylineOdds: "-113",
        underdogMoneylineTeamCode: "HOU",
        underdogMoneylineOdds: "-113",
        totalPoints: "36.5",
        moneylineDisplay: "HOU -113 / PIT -113",
        sportsbook: "FanDuel",
        sportsbookEnum: .fanduel,
        lastUpdated: Date(),
        allBookOdds: nil
    )
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        Image("BG3")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.15)
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            HStack {
                Text("Wild Card")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                RefreshCountdownTimerView()
                
                Spacer()
                
                Button {
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
            
            ScrollView {
                VStack(spacing: 10) {
                    PlayoffGameDetailCard(
                        game: mockLiveGame,
                        displayOdds: mockOdds,
                        scoreSize: 80,
                        scoreOffset: 24
                    )
                    .padding(.top, 4)
                    
                    PlayoffLiveGameSituationCard(
                        situation: mockLiveGame.liveSituation!,
                        game: mockLiveGame,
                        onLastPlayTap: { _ in }
                    )
                    .padding(.horizontal, 16)
                    
                    PlayoffOddsBar(
                        displayOdds: mockOdds,
                        currentSportsbook: .fanduel,
                        onBookPickerTap: { }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
        }
        .frame(width: 480)
        .scaleEffect(0.75)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .white.opacity(0.3), radius: 30, x: 0, y: 0)
        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 10)
        .scaleEffect(0.85)
    }
    .environment(TeamAssetManager())
    .preferredColorScheme(.dark)
}