//
//  FantasyPosition.swift
//  BigWarRoom
//
//  Position filter options for Fantasy views
//

import Foundation

/// Position filter options for Fantasy Matchup Detail view
enum FantasyPosition: String, CaseIterable, Identifiable {
    case all = "all"
    case qb = "QB"
    case rb = "RB" 
    case wr = "WR"
    case te = "TE"
    case k = "K"
    case dst = "D/ST"
    case flex = "FLEX"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "ALL"
        case .qb: return "QB"
        case .rb: return "RB"
        case .wr: return "WR"
        case .te: return "TE"
        case .k: return "K"
        case .dst: return "D/ST"
        case .flex: return "FLEX"
        }
    }
}