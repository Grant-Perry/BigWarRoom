//
//  PlayoffBracketConferenceColumn.swift
//  BigWarRoom
//
//  AFC or NFC conference column for playoff bracket portrait view
//

import SwiftUI

struct PlayoffBracketConferenceColumn: View {
    let conference: PlayoffGame.Conference
    let bracket: PlayoffBracket
    let currentRound: PlayoffRound  // 🔥 NEW: Filter what we display
    let getSeedsForConference: (PlayoffBracket, PlayoffGame.Conference) -> [Int: PlayoffTeam]
    let findGame: (PlayoffTeam, PlayoffTeam, [PlayoffGame]) -> PlayoffGame?
    let determineWinner: (PlayoffGame?) -> String?
    let shouldShowGameTime: (Date) -> Bool
    
    var body: some View {
        VStack(spacing: 6) {
            // Conference label
            Text(conference.rawValue)
                .font(.custom("BebasNeue-Regular", size: 24))
                .foregroundColor(.white)
            
            // Get seeds and games
            let seeds = getSeedsForConference(bracket, conference)
            let games = conference == .afc ? bracket.afcGames : bracket.nfcGames
            
            // 🔥 Show different layouts based on current round
            switch currentRound {
            case .wildCard:
                wildCardView(seeds: seeds, games: games)
            case .divisional:
                divisionalView(seeds: seeds, games: games)
            case .conference:
                conferenceChampionshipView(games: games)
            case .superBowl:
                EmptyView() // Super Bowl is handled separately
            }
        }
    }
    
    // MARK: - Wild Card Round View
    @ViewBuilder
    private func wildCardView(seeds: [Int: PlayoffTeam], games: [PlayoffGame]) -> some View {
        VStack(spacing: 0) {
            // 1 seed (bye)
            if let seed1 = seeds[1] {
                PlayoffBracketTeamCard(
                    team: seed1,
                    seed: 1,
                    game: nil,
                    isWinner: false,
                    determineWinner: determineWinner
                )
            }
            
            Spacer().frame(height: 20)
            
            // 5 vs 4 matchup
            if let seed5 = seeds[5], let seed4 = seeds[4] {
                matchupView(team1: seed5, team2: seed4, games: games)
            }
            
            Spacer().frame(height: 24)
            
            // 6 vs 3 matchup
            if let seed6 = seeds[6], let seed3 = seeds[3] {
                matchupView(team1: seed6, team2: seed3, games: games)
            }
            
            Spacer().frame(height: 24)
            
            // 7 vs 2 matchup
            if let seed7 = seeds[7], let seed2 = seeds[2] {
                matchupView(team1: seed7, team2: seed2, games: games)
            }
        }
    }
    
    // MARK: - Divisional Round View
    @ViewBuilder
    private func divisionalView(seeds: [Int: PlayoffTeam], games: [PlayoffGame]) -> some View {
        VStack(spacing: 24) {
            // Get divisional round games (they should have actual teams, not just seeds)
            let divisionalGames = games.filter { $0.round == .divisional }
            
            ForEach(divisionalGames, id: \.id) { game in
                VStack(spacing: 0) {
                    // Game header
                    PlayoffBracketGameHeader(
                        game: game,
                        shouldShowGameTime: shouldShowGameTime
                    )
                    
                    HStack(spacing: 0) {
                        // Bracket connector line
                        BracketConnectorLine()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 20, height: 120)
                        
                        VStack(spacing: 20) {
                            // Away team
                            PlayoffBracketTeamCard(
                                team: game.awayTeam,
                                seed: game.awayTeam.seed ?? 0,
                                game: game,
                                isWinner: determineWinner(game) == game.awayTeam.abbreviation,
                                determineWinner: determineWinner
                            )
                            
                            // Home team
                            PlayoffBracketTeamCard(
                                team: game.homeTeam,
                                seed: game.homeTeam.seed ?? 0,
                                game: game,
                                isWinner: determineWinner(game) == game.homeTeam.abbreviation,
                                determineWinner: determineWinner
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Conference Championship View
    @ViewBuilder
    private func conferenceChampionshipView(games: [PlayoffGame]) -> some View {
        VStack(spacing: 24) {
            // Get conference championship game
            if let confGame = games.first(where: { $0.round == .conference }) {
                VStack(spacing: 0) {
                    // Game header
                    PlayoffBracketGameHeader(
                        game: confGame,
                        shouldShowGameTime: shouldShowGameTime
                    )
                    
                    HStack(spacing: 0) {
                        // Bracket connector line
                        BracketConnectorLine()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 20, height: 120)
                        
                        VStack(spacing: 20) {
                            // Away team
                            PlayoffBracketTeamCard(
                                team: confGame.awayTeam,
                                seed: confGame.awayTeam.seed ?? 0,
                                game: confGame,
                                isWinner: determineWinner(confGame) == confGame.awayTeam.abbreviation,
                                determineWinner: determineWinner
                            )
                            
                            // Home team
                            PlayoffBracketTeamCard(
                                team: confGame.homeTeam,
                                seed: confGame.homeTeam.seed ?? 0,
                                game: confGame,
                                isWinner: determineWinner(confGame) == confGame.homeTeam.abbreviation,
                                determineWinner: determineWinner
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Reusable Matchup View
    @ViewBuilder
    private func matchupView(team1: PlayoffTeam, team2: PlayoffTeam, games: [PlayoffGame]) -> some View {
        let game = findGame(team1, team2, games)
        let winner = determineWinner(game)
        
        VStack(spacing: 0) {
            // Game day info at TOP
            if let matchup = game {
                PlayoffBracketGameHeader(
                    game: matchup,
                    shouldShowGameTime: shouldShowGameTime
                )
            }
            
            HStack(spacing: 0) {
                // Bracket connector line with opacity
                BracketConnectorLine()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: 20, height: 120)
                
                VStack(spacing: 20) {
                    PlayoffBracketTeamCard(
                        team: team1,
                        seed: team1.seed ?? 0,
                        game: game,
                        isWinner: winner == team1.abbreviation,
                        determineWinner: determineWinner
                    )
                    PlayoffBracketTeamCard(
                        team: team2,
                        seed: team2.seed ?? 0,
                        game: game,
                        isWinner: winner == team2.abbreviation,
                        determineWinner: determineWinner
                    )
                }
            }
        }
    }
}