//
//  GameDisplayInfo.swift
//  BigWarRoom
//
//  Shared display model for center coordinator and schedule mini-cards.
//

import Foundation

/// View-facing, presentation-only game info for the selected/hovered team.
struct GameDisplayInfo {
    let opponent: String
    let scoreDisplay: String
    let teamScore: String
    let opponentScore: String
    let gameTime: String
    let isLive: Bool
    let hasStarted: Bool
    let isWinning: Bool
    let isLosing: Bool
    let isByeWeek: Bool

    // Mini card details
    let isHome: Bool
    let actualAwayTeam: String
    let actualHomeTeam: String
    let actualAwayScore: Int
    let actualHomeScore: Int
}