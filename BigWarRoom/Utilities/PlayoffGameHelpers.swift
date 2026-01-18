//
//  PlayoffGameHelpers.swift
//  BigWarRoom
//
//  Helper utilities for playoff game data operations
//

import Foundation

enum PlayoffGameHelpers {
    
    /// Get seeds dictionary for a specific conference
    static func getSeedsForConference(bracket: PlayoffBracket, conference: PlayoffGame.Conference) -> [Int: PlayoffTeam] {
        var seeds: [Int: PlayoffTeam] = [:]
        
        let games = conference == .afc ? bracket.afcGames : bracket.nfcGames
        
        for game in games.reversed() {
            if let awaySeed = game.awayTeam.seed {
                seeds[awaySeed] = game.awayTeam
            }
            if let homeSeed = game.homeTeam.seed {
                seeds[homeSeed] = game.homeTeam
            }
        }
        
        return seeds
    }
    
    /// Find a game between two teams
    static func findGame(team1: PlayoffTeam, team2: PlayoffTeam, in games: [PlayoffGame]) -> PlayoffGame? {
        games.first { game in
            (game.homeTeam.abbreviation == team1.abbreviation && game.awayTeam.abbreviation == team2.abbreviation) ||
            (game.homeTeam.abbreviation == team2.abbreviation && game.awayTeam.abbreviation == team1.abbreviation)
        }
    }
    
    /// Find game by ID in bracket
    static func findGame(by id: String, in bracket: PlayoffBracket) -> PlayoffGame? {
        let allGames = bracket.afcGames + bracket.nfcGames + (bracket.superBowl != nil ? [bracket.superBowl!] : [])
        let game = allGames.first { $0.id == id }
        
        if let g = game {
            DebugPrint(mode: .bracketTimer, "🔍 [GAME LOOKUP] Found game \(id): \(g.awayTeam.abbreviation)@\(g.homeTeam.abbreviation), Status: \(g.status.displayText), Away: \(g.awayTeam.score ?? 0), Home: \(g.homeTeam.score ?? 0)")
        } else {
            DebugPrint(mode: .bracketTimer, "⚠️ [GAME LOOKUP] Could not find game \(id) in bracket!")
        }
        
        return game
    }
    
    /// Determine the winner of a completed game
    static func determineWinner(game: PlayoffGame?) -> String? {
        guard let game = game, game.isCompleted else { return nil }
        guard let homeScore = game.homeTeam.score, let awayScore = game.awayTeam.score else { return nil }
        
        if homeScore > awayScore {
            return game.homeTeam.abbreviation
        } else if awayScore > homeScore {
            return game.awayTeam.abbreviation
        }
        return nil
    }
    
    /// Check if bracket has upcoming games in next 24 hours
    static func hasUpcomingGames(bracket: PlayoffBracket) -> Bool {
        let now = Date()
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        
        let allGames = bracket.afcGames + bracket.nfcGames + (bracket.superBowl != nil ? [bracket.superBowl!] : [])
        
        return allGames.contains { game in
            game.status == .scheduled && game.gameDate >= now && game.gameDate <= todayEnd
        }
    }
}