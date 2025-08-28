//
//  NFLTeam.swift
//  BigWarRoom
//
//  NFL Team data with colors, logos, and branding
//
// MARK: -> NFL Team Model

import SwiftUI
import Foundation

struct NFLTeam: Identifiable, Hashable {
    let id: String // Team code (e.g., "CIN")
    let name: String
    let city: String
    let conference: Conference
    let division: Division
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color?
    
    /// Full team name (e.g., "Cincinnati Bengals")
    var fullName: String {
        "\(city) \(name)"
    }
    
    /// Logo asset name for bundled images
    var logoAssetName: String {
        "logo_\(id.lowercased())"
    }
    
    /// Team colors as gradient
    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Background color for cards/UI elements
    var backgroundColor: Color {
        primaryColor.opacity(0.1)
    }
    
    /// Border color for outlines
    var borderColor: Color {
        primaryColor.opacity(0.3)
    }
}

// MARK: -> Conference & Division
enum Conference: String, CaseIterable {
    case afc = "AFC"
    case nfc = "NFC"
}

enum Division: String, CaseIterable {
    case north = "North"
    case south = "South"
    case east = "East"
    case west = "West"
    
    var displayName: String { rawValue }
}

// MARK: -> Team Directory
extension NFLTeam {
    /// All 32 NFL teams with accurate branding
    static let allTeams: [NFLTeam] = [
        // AFC East
        NFLTeam(id: "BUF", name: "Bills", city: "Buffalo", conference: .afc, division: .east,
                primaryColor: Color(red: 0/255, green: 51/255, blue: 141/255),
                secondaryColor: Color(red: 198/255, green: 12/255, blue: 48/255),
                accentColor: Color.white),
        
        NFLTeam(id: "MIA", name: "Dolphins", city: "Miami", conference: .afc, division: .east,
                primaryColor: Color(red: 0/255, green: 142/255, blue: 151/255),
                secondaryColor: Color(red: 252/255, green: 76/255, blue: 2/255),
                accentColor: Color.white),
        
        NFLTeam(id: "NE", name: "Patriots", city: "New England", conference: .afc, division: .east,
                primaryColor: Color(red: 0/255, green: 34/255, blue: 68/255),
                secondaryColor: Color(red: 198/255, green: 12/255, blue: 48/255),
                accentColor: Color.white),
        
        NFLTeam(id: "NYJ", name: "Jets", city: "New York", conference: .afc, division: .east,
                primaryColor: Color(red: 18/255, green: 87/255, blue: 64/255),
                secondaryColor: Color.white,
                accentColor: Color.black),
        
        // AFC North
        NFLTeam(id: "BAL", name: "Ravens", city: "Baltimore", conference: .afc, division: .north,
                primaryColor: Color(red: 26/255, green: 25/255, blue: 95/255),
                secondaryColor: Color.black,
                accentColor: Color(red: 158/255, green: 124/255, blue: 12/255)),
        
        NFLTeam(id: "CIN", name: "Bengals", city: "Cincinnati", conference: .afc, division: .north,
                primaryColor: Color(red: 251/255, green: 79/255, blue: 20/255),
                secondaryColor: Color.black,
                accentColor: Color.white),
        
        NFLTeam(id: "CLE", name: "Browns", city: "Cleveland", conference: .afc, division: .north,
                primaryColor: Color(red: 49/255, green: 29/255, blue: 0/255),
                secondaryColor: Color(red: 251/255, green: 79/255, blue: 20/255),
                accentColor: Color.white),
        
        NFLTeam(id: "PIT", name: "Steelers", city: "Pittsburgh", conference: .afc, division: .north,
                primaryColor: Color.black,
                secondaryColor: Color(red: 255/255, green: 182/255, blue: 18/255),
                accentColor: Color.white),
        
        // AFC South
        NFLTeam(id: "HOU", name: "Texans", city: "Houston", conference: .afc, division: .south,
                primaryColor: Color(red: 3/255, green: 32/255, blue: 47/255),
                secondaryColor: Color(red: 167/255, green: 25/255, blue: 48/255),
                accentColor: Color.white),
        
        NFLTeam(id: "IND", name: "Colts", city: "Indianapolis", conference: .afc, division: .south,
                primaryColor: Color(red: 0/255, green: 44/255, blue: 95/255),
                secondaryColor: Color.white,
                accentColor: Color(red: 162/255, green: 170/255, blue: 173/255)),
        
        NFLTeam(id: "JAX", name: "Jaguars", city: "Jacksonville", conference: .afc, division: .south,
                primaryColor: Color(red: 0/255, green: 103/255, blue: 120/255),
                secondaryColor: Color(red: 215/255, green: 162/255, blue: 42/255),
                accentColor: Color.black),
        
        NFLTeam(id: "TEN", name: "Titans", city: "Tennessee", conference: .afc, division: .south,
                primaryColor: Color(red: 0/255, green: 34/255, blue: 68/255),
                secondaryColor: Color(red: 75/255, green: 146/255, blue: 219/255),
                accentColor: Color(red: 198/255, green: 12/255, blue: 48/255)),
        
        // AFC West
        NFLTeam(id: "DEN", name: "Broncos", city: "Denver", conference: .afc, division: .west,
                primaryColor: Color(red: 251/255, green: 79/255, blue: 20/255),
                secondaryColor: Color(red: 0/255, green: 34/255, blue: 68/255),
                accentColor: Color.white),
        
        NFLTeam(id: "KC", name: "Chiefs", city: "Kansas City", conference: .afc, division: .west,
                primaryColor: Color(red: 227/255, green: 24/255, blue: 55/255),
                secondaryColor: Color(red: 255/255, green: 184/255, blue: 28/255),
                accentColor: Color.white),
        
        NFLTeam(id: "LV", name: "Raiders", city: "Las Vegas", conference: .afc, division: .west,
                primaryColor: Color.black,
                secondaryColor: Color(red: 165/255, green: 172/255, blue: 175/255),
                accentColor: Color.white),
        
        NFLTeam(id: "LAC", name: "Chargers", city: "Los Angeles", conference: .afc, division: .west,
                primaryColor: Color(red: 0/255, green: 128/255, blue: 198/255),
                secondaryColor: Color(red: 255/255, green: 194/255, blue: 14/255),
                accentColor: Color.white),
        
        // NFC East
        NFLTeam(id: "DAL", name: "Cowboys", city: "Dallas", conference: .nfc, division: .east,
                primaryColor: Color(red: 0/255, green: 34/255, blue: 68/255),
                secondaryColor: Color(red: 134/255, green: 147/255, blue: 151/255),
                accentColor: Color.white),
        
        NFLTeam(id: "NYG", name: "Giants", city: "New York", conference: .nfc, division: .east,
                primaryColor: Color(red: 1/255, green: 35/255, blue: 82/255),
                secondaryColor: Color(red: 163/255, green: 13/255, blue: 45/255),
                accentColor: Color.white),
        
        NFLTeam(id: "PHI", name: "Eagles", city: "Philadelphia", conference: .nfc, division: .east,
                primaryColor: Color(red: 0/255, green: 76/255, blue: 84/255),
                secondaryColor: Color(red: 165/255, green: 172/255, blue: 175/255),
                accentColor: Color.white),
        
        NFLTeam(id: "WAS", name: "Commanders", city: "Washington", conference: .nfc, division: .east,
                primaryColor: Color(red: 90/255, green: 20/255, blue: 20/255),
                secondaryColor: Color(red: 255/255, green: 182/255, blue: 18/255),
                accentColor: Color.white),
        
        // NFC North
        NFLTeam(id: "CHI", name: "Bears", city: "Chicago", conference: .nfc, division: .north,
                primaryColor: Color(red: 11/255, green: 22/255, blue: 42/255),
                secondaryColor: Color(red: 200/255, green: 56/255, blue: 3/255),
                accentColor: Color.white),
        
        NFLTeam(id: "DET", name: "Lions", city: "Detroit", conference: .nfc, division: .north,
                primaryColor: Color(red: 0/255, green: 118/255, blue: 182/255),
                secondaryColor: Color(red: 176/255, green: 183/255, blue: 188/255),
                accentColor: Color.white),
        
        NFLTeam(id: "GB", name: "Packers", city: "Green Bay", conference: .nfc, division: .north,
                primaryColor: Color(red: 24/255, green: 48/255, blue: 40/255),
                secondaryColor: Color(red: 255/255, green: 184/255, blue: 28/255),
                accentColor: Color.white),
        
        NFLTeam(id: "MIN", name: "Vikings", city: "Minnesota", conference: .nfc, division: .north,
                primaryColor: Color(red: 79/255, green: 38/255, blue: 131/255),
                secondaryColor: Color(red: 255/255, green: 198/255, blue: 47/255),
                accentColor: Color.white),
        
        // NFC South
        NFLTeam(id: "ATL", name: "Falcons", city: "Atlanta", conference: .nfc, division: .south,
                primaryColor: Color(red: 167/255, green: 25/255, blue: 48/255),
                secondaryColor: Color.black,
                accentColor: Color(red: 165/255, green: 172/255, blue: 175/255)),
        
        NFLTeam(id: "CAR", name: "Panthers", city: "Carolina", conference: .nfc, division: .south,
                primaryColor: Color(red: 0/255, green: 133/255, blue: 202/255),
                secondaryColor: Color.black,
                accentColor: Color(red: 191/255, green: 192/255, blue: 191/255)),
        
        NFLTeam(id: "NO", name: "Saints", city: "New Orleans", conference: .nfc, division: .south,
                primaryColor: Color(red: 211/255, green: 188/255, blue: 141/255),
                secondaryColor: Color.black,
                accentColor: Color.white),
        
        NFLTeam(id: "TB", name: "Buccaneers", city: "Tampa Bay", conference: .nfc, division: .south,
                primaryColor: Color(red: 213/255, green: 10/255, blue: 10/255),
                secondaryColor: Color(red: 52/255, green: 48/255, blue: 43/255),
                accentColor: Color(red: 255/255, green: 121/255, blue: 0/255)),
        
        // NFC West
        NFLTeam(id: "ARI", name: "Cardinals", city: "Arizona", conference: .nfc, division: .west,
                primaryColor: Color(red: 151/255, green: 35/255, blue: 63/255),
                secondaryColor: Color(red: 255/255, green: 182/255, blue: 18/255),
                accentColor: Color.white),
        
        NFLTeam(id: "LAR", name: "Rams", city: "Los Angeles", conference: .nfc, division: .west,
                primaryColor: Color(red: 0/255, green: 53/255, blue: 148/255),
                secondaryColor: Color(red: 255/255, green: 209/255, blue: 0/255),
                accentColor: Color.white),
        
        NFLTeam(id: "SF", name: "49ers", city: "San Francisco", conference: .nfc, division: .west,
                primaryColor: Color(red: 170/255, green: 0/255, blue: 0/255),
                secondaryColor: Color(red: 173/255, green: 153/255, blue: 93/255),
                accentColor: Color.white),
        
        NFLTeam(id: "SEA", name: "Seahawks", city: "Seattle", conference: .nfc, division: .west,
                primaryColor: Color(red: 0/255, green: 34/255, blue: 68/255),
                secondaryColor: Color(red: 105/255, green: 190/255, blue: 40/255),
                accentColor: Color(red: 165/255, green: 172/255, blue: 175/255))
    ]
    
    /// Team lookup by code
    static func team(for code: String) -> NFLTeam? {
        return allTeams.first { $0.id.uppercased() == code.uppercased() }
    }
    
    /// Team lookup dictionary for O(1) access
    static let teamLookup: [String: NFLTeam] = {
        Dictionary(uniqueKeysWithValues: allTeams.map { ($0.id, $0) })
    }()
}