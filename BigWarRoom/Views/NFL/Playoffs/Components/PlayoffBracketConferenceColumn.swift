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
                
                // 5 vs 4 matchup with bracket line
                if let seed5 = seeds[5], let seed4 = seeds[4] {
                    let game = findGame(seed5, seed4, games)
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
                                    team: seed5,
                                    seed: 5,
                                    game: game,
                                    isWinner: winner == seed5.abbreviation,
                                    determineWinner: determineWinner
                                )
                                PlayoffBracketTeamCard(
                                    team: seed4,
                                    seed: 4,
                                    game: game,
                                    isWinner: winner == seed4.abbreviation,
                                    determineWinner: determineWinner
                                )
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 24)
                
                // 6 vs 3 matchup with bracket line
                if let seed6 = seeds[6], let seed3 = seeds[3] {
                    let game = findGame(seed6, seed3, games)
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
                                    team: seed6,
                                    seed: 6,
                                    game: game,
                                    isWinner: winner == seed6.abbreviation,
                                    determineWinner: determineWinner
                                )
                                PlayoffBracketTeamCard(
                                    team: seed3,
                                    seed: 3,
                                    game: game,
                                    isWinner: winner == seed3.abbreviation,
                                    determineWinner: determineWinner
                                )
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 24)
                
                // 7 vs 2 matchup with bracket line
                if let seed7 = seeds[7], let seed2 = seeds[2] {
                    let game = findGame(seed7, seed2, games)
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
                                    team: seed7,
                                    seed: 7,
                                    game: game,
                                    isWinner: winner == seed7.abbreviation,
                                    determineWinner: determineWinner
                                )
                                PlayoffBracketTeamCard(
                                    team: seed2,
                                    seed: 2,
                                    game: game,
                                    isWinner: winner == seed2.abbreviation,
                                    determineWinner: determineWinner
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}