//
//  BettingOddsHelpers.swift
//  BigWarRoom
//
//  Helper utilities for betting odds display logic
//

import Foundation

enum BettingOddsHelpers {
    
    /// Get display odds for a specific sportsbook
    static func getDisplayOdds(from odds: GameBettingOdds?, book: Sportsbook) -> GameBettingOdds? {
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