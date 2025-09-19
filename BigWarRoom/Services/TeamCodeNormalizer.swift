//
//  TeamCodeNormalizer.swift
//  BigWarRoom
//
//  Handles team code normalization (WSH/WAS, JAX/JAC, etc.) across the entire app
//

import Foundation

/// **TeamCodeNormalizer**
/// 
/// Single source of truth for team code mapping and normalization
/// Fixes inconsistencies like WSH vs WAS, JAX vs JAC, etc.
struct TeamCodeNormalizer {
    
    /// The canonical team codes that should be used throughout the app
    static let canonicalTeamCodes: [String: String] = [
        // AFC East
        "BUF": "BUF",
        "MIA": "MIA", 
        "NE": "NE",
        "NEP": "NE",        // Patriots alternate
        "NYJ": "NYJ",
        
        // AFC North
        "BAL": "BAL",
        "CIN": "CIN",
        "CLE": "CLE",
        "PIT": "PIT",
        
        // AFC South
        "HOU": "HOU",
        "IND": "IND",
        "JAX": "JAX",
        "JAC": "JAX",       // 🔥 Jacksonville alternate
        "TEN": "TEN",
        
        // AFC West
        "DEN": "DEN",
        "KC": "KC",
        "LV": "LV",
        "LVR": "LV",        // Las Vegas alternate
        "OAK": "LV",        // Oakland -> Las Vegas
        "LAC": "LAC",
        "SD": "LAC",        // San Diego -> Los Angeles
        
        // NFC East
        "DAL": "DAL",
        "NYG": "NYG",
        "PHI": "PHI",
        "WSH": "WAS",       // 🔥 KEY FIX: Washington normalization
        "WAS": "WAS",
        
        // NFC North
        "CHI": "CHI",
        "DET": "DET", 
        "GB": "GB",
        "MIN": "MIN",
        
        // NFC South
        "ATL": "ATL",
        "CAR": "CAR",
        "NO": "NO",
        "TB": "TB",
        
        // NFC West
        "ARI": "ARI",
        "LAR": "LAR",
        "STL": "LAR",       // St. Louis -> Los Angeles
        "SEA": "SEA",
        "SF": "SF"
    ]
    
    /// Normalize a team code to its canonical form
    /// - Parameter teamCode: Raw team code (e.g., "WSH", "JAC", "OAK")
    /// - Returns: Canonical team code (e.g., "WAS", "JAX", "LV")
    static func normalize(_ teamCode: String?) -> String? {
        guard let teamCode = teamCode?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        
        return canonicalTeamCodes[teamCode] ?? teamCode
    }
    
    /// Get all aliases for a team code (including the canonical form)
    /// - Parameter teamCode: Team code to get aliases for
    /// - Returns: Array of all known aliases for this team
    static func aliases(for teamCode: String) -> [String] {
        let canonical = normalize(teamCode) ?? teamCode.uppercased()
        
        var aliases: [String] = [canonical]
        
        // Add all known aliases that map to this canonical code
        for (alias, canonicalForm) in canonicalTeamCodes {
            if canonicalForm == canonical && alias != canonical {
                aliases.append(alias)
            }
        }
        
        return aliases
    }
    
    /// Check if two team codes represent the same team
    /// - Parameters:
    ///   - teamCode1: First team code
    ///   - teamCode2: Second team code  
    /// - Returns: True if they represent the same team
    static func areEqual(_ teamCode1: String?, _ teamCode2: String?) -> Bool {
        let normalized1 = normalize(teamCode1)
        let normalized2 = normalize(teamCode2)
        
        return normalized1 == normalized2 && normalized1 != nil
    }
    
    /// Get team name for display purposes
    /// - Parameter teamCode: Team code
    /// - Returns: Full team name
    static func displayName(for teamCode: String?) -> String? {
        guard let canonical = normalize(teamCode) else { return nil }
        
        let teamNames: [String: String] = [
            // AFC East
            "BUF": "Buffalo Bills",
            "MIA": "Miami Dolphins",
            "NE": "New England Patriots", 
            "NYJ": "New York Jets",
            
            // AFC North
            "BAL": "Baltimore Ravens",
            "CIN": "Cincinnati Bengals",
            "CLE": "Cleveland Browns",
            "PIT": "Pittsburgh Steelers",
            
            // AFC South
            "HOU": "Houston Texans",
            "IND": "Indianapolis Colts",
            "JAX": "Jacksonville Jaguars",
            "TEN": "Tennessee Titans",
            
            // AFC West
            "DEN": "Denver Broncos",
            "KC": "Kansas City Chiefs",
            "LV": "Las Vegas Raiders",
            "LAC": "Los Angeles Chargers",
            
            // NFC East
            "DAL": "Dallas Cowboys",
            "NYG": "New York Giants",
            "PHI": "Philadelphia Eagles",
            "WAS": "Washington Commanders",
            
            // NFC North
            "CHI": "Chicago Bears",
            "DET": "Detroit Lions",
            "GB": "Green Bay Packers", 
            "MIN": "Minnesota Vikings",
            
            // NFC South
            "ATL": "Atlanta Falcons",
            "CAR": "Carolina Panthers",
            "NO": "New Orleans Saints",
            "TB": "Tampa Bay Buccaneers",
            
            // NFC West
            "ARI": "Arizona Cardinals",
            "LAR": "Los Angeles Rams",
            "SEA": "Seattle Seahawks",
            "SF": "San Francisco 49ers"
        ]
        
        return teamNames[canonical]
    }
}

// MARK: - Helper Extensions

extension String {
    /// Normalize this string as a team code
    var normalizedTeamCode: String? {
        return TeamCodeNormalizer.normalize(self)
    }
}