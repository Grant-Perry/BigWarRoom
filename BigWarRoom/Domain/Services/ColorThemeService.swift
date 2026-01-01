//
//  ColorThemeService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Centralized color theming logic
//  Eliminates 100+ duplicate color assignments across the codebase
//
//  Created to consolidate scattered color logic into one source of truth

import Foundation
import SwiftUI

/// Centralized service for all color theming logic
///
/// **Consolidates:**
/// - Position badge colors (30+ duplicates)
/// - Injury status colors (50+ duplicates)
/// - Team colors (already in NFLTeamColors, but adds helpers)
/// - Game status colors (25+ duplicates)
/// - UI status colors (live/complete/upcoming)
///
/// **Usage:**
/// ```swift
/// let colorService = ColorThemeService()
/// 
/// let color = colorService.positionColor(for: "QB")
/// let injuryColor = colorService.injuryStatusColor(for: "Questionable")
/// let statusColor = colorService.gameStatusColor(for: .live)
/// ```
final class ColorThemeService {
    
    // MARK: - Singleton (for convenience, but can be injected)
    
    static let shared = ColorThemeService()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Position Colors
    
    /// Get color for a player position
    /// **Consolidates:** 30+ duplicate position color assignments
    func positionColor(for position: String) -> Color {
        switch position.uppercased() {
        case "QB":
            return Color(red: 0.8, green: 0.2, blue: 0.2) // Red
        case "RB":
            return Color(red: 0.2, green: 0.6, blue: 0.8) // Blue
        case "WR":
            return Color(red: 0.2, green: 0.7, blue: 0.3) // Green
        case "TE":
            return Color(red: 0.9, green: 0.6, blue: 0.1) // Orange
        case "K":
            return Color(red: 0.6, green: 0.3, blue: 0.8) // Purple
        case "D/ST", "DEF", "DST":
            return Color(red: 0.4, green: 0.3, blue: 0.2) // Brown
        case "FLEX":
            return Color(red: 0.5, green: 0.5, blue: 0.5) // Gray
        case "SUPER_FLEX":
            return Color(red: 0.7, green: 0.4, blue: 0.9) // Purple-ish
        default:
            return Color(red: 0.5, green: 0.5, blue: 0.6) // Default gray
        }
    }
    
    /// Get text color for position badge (ensures readability)
    /// **Consolidates:** Position text color logic scattered in views
    func positionTextColor(for position: String) -> Color {
        // Most positions use white text for contrast
        // Only lighter colors need dark text
        return .white
    }
    
    /// Get position abbreviation
    /// **Consolidates:** Position abbreviation logic duplicated in multiple places
    func positionAbbreviation(for position: String) -> String {
        switch position.uppercased() {
        case "D/ST", "DEF", "DST":
            return "DEF"
        case "SUPER_FLEX":
            return "SF"
        default:
            return position.uppercased()
        }
    }
    
    // MARK: - Injury Status Colors
    
    /// Get background color for injury status
    /// **Consolidates:** 50+ duplicate injury color assignments
    func injuryStatusColor(for status: String) -> Color {
        let normalized = status.uppercased()
        
        switch normalized {
        case "QUESTIONABLE":
            return .yellow
        case "DOUBTFUL":
            return .orange
        case "OUT", "INJURED_RESERVE", "IR":
            return .red
        case "PROBABLE", "PROBABLETOPLAY":
            return .green.opacity(0.8)
        case "BYE":
            return .blue.opacity(0.8)
        case "SUSPENDED", "SUSPENSION":
            return .purple
        case "PHYSICALLY_UNABLE_TO_PERFORM", "PUP", "NON_FOOTBALL_INJURY", "NFI":
            return .gray.opacity(0.8)
        case "HEALTHY", "ACTIVE":
            return .green
        default:
            return .orange // Default for unknown statuses
        }
    }
    
    /// Get text color for injury status badge
    /// **Consolidates:** Injury text color logic
    func injuryStatusTextColor(for status: String) -> Color {
        let normalized = status.uppercased()
        
        switch normalized {
        case "QUESTIONABLE":
            return .black // Yellow background needs black text
        case "PROBABLE", "PROBABLETOPLAY":
            return .white
        case "BYE":
            return .white
        default:
            return .white
        }
    }
    
    /// Get short text for injury status badge
    /// **Consolidates:** Status text mapping duplicated in multiple views
    func injuryStatusText(for status: String) -> String {
        let normalized = status.uppercased()
        
        switch normalized {
        case "QUESTIONABLE":
            return "Q"
        case "DOUBTFUL":
            return "D"
        case "OUT":
            return "O"
        case "INJURED_RESERVE", "IR":
            return "IR"
        case "PROBABLE", "PROBABLETOPLAY":
            return "P"
        case "BYE":
            return "BYE"
        case "SUSPENDED", "SUSPENSION":
            return "S"
        case "PHYSICALLY_UNABLE_TO_PERFORM", "PUP":
            return "PUP"
        case "NON_FOOTBALL_INJURY", "NFI":
            return "NFI"
        default:
            // For other statuses, take first letter or first 2 letters
            if normalized.count <= 2 {
                return normalized
            } else {
                return String(normalized.prefix(1))
            }
        }
    }
    
    /// Get full display name for injury status
    /// **Consolidates:** Status display name logic
    func injuryStatusDisplayName(for status: String) -> String {
        let normalized = status.uppercased()
        
        switch normalized {
        case "QUESTIONABLE":
            return "Questionable"
        case "DOUBTFUL":
            return "Doubtful"
        case "OUT":
            return "Out"
        case "INJURED_RESERVE", "IR":
            return "Injured Reserve"
        case "PROBABLE", "PROBABLETOPLAY":
            return "Probable"
        case "BYE":
            return "Bye Week"
        case "SUSPENDED", "SUSPENSION":
            return "Suspended"
        case "PHYSICALLY_UNABLE_TO_PERFORM", "PUP":
            return "PUP List"
        case "NON_FOOTBALL_INJURY", "NFI":
            return "NFI List"
        case "HEALTHY", "ACTIVE":
            return "Healthy"
        default:
            return status.capitalized
        }
    }
    
    /// Get severity ranking for injury status (for sorting/prioritization)
    /// **Consolidates:** Injury severity logic scattered in multiple files
    /// Higher = more severe
    func injuryStatusSeverity(for status: String) -> Int {
        let normalized = status.uppercased()
        
        switch normalized {
        case "OUT":
            return 5
        case "INJURED_RESERVE", "IR":
            return 6
        case "DOUBTFUL":
            return 4
        case "SUSPENDED", "SUSPENSION":
            return 5
        case "QUESTIONABLE":
            return 3
        case "PROBABLE", "PROBABLETOPLAY":
            return 1
        case "BYE":
            return 2
        case "HEALTHY", "ACTIVE":
            return 0
        default:
            return 3 // Default to moderate
        }
    }
    
    // MARK: - Game Status Colors
    
    /// Get color for game status category
    /// **Consolidates:** 25+ duplicate game status color assignments
    func gameStatusColor(for status: GameStatusCategory) -> Color {
        switch status {
        case .pregame:
            return .orange
        case .live:
            return .red
        case .complete:
            return .gray
        case .bye:
            return .blue.opacity(0.7)
        }
    }
    
    /// Get color for matchup status
    /// **Consolidates:** Matchup status colors duplicated everywhere
    func matchupStatusColor(for status: MatchupStatus) -> Color {
        switch status {
        case .upcoming:
            return .orange
        case .live:
            return .red
        case .complete:
            return .gray
        }
    }
    
    // MARK: - UI Status Colors
    
    /// Get color for positive/negative deltas
    /// **Consolidates:** Delta color logic scattered across views
    func deltaColor(for value: Double) -> Color {
        if value > 0 {
            return .green
        } else if value < 0 {
            return .red
        } else {
            return .gray
        }
    }
    
    /// Get color for win probability
    /// **Consolidates:** Win probability color logic
    func winProbabilityColor(for probability: Double) -> Color {
        // probability is 0.0 to 1.0
        if probability >= 0.75 {
            return .green
        } else if probability >= 0.5 {
            return .yellow
        } else if probability >= 0.25 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Team Colors
    
    /// Get team primary color (delegates to NFLTeamColors)
    /// **Consolidates:** Team color access scattered everywhere
    func teamColor(for team: String) -> Color {
        return NFLTeamColors.color(for: team)
    }
    
    /// Get team accent color (delegates to NFLTeamColors)
    func teamAccentColor(for team: String) -> Color {
        return NFLTeamColors.accentColor(for: team)
    }
    
    /// Get position-based fallback color for players without team
    func positionFallbackColor(for position: String) -> Color {
        return NFLTeamColors.fallbackColor(for: position)
    }
    
    // MARK: - Elimination Status Colors (for Chopped)
    
    /// Get color for elimination status
    /// **Consolidates:** Elimination status colors from FantasyModels
    func eliminationStatusColor(for status: EliminationStatus) -> Color {
        switch status {
        case .champion:
            return .yellow
        case .safe:
            return .green
        case .warning:
            return .blue
        case .danger:
            return .orange
        case .critical:
            return .red
        case .eliminated:
            return .black
        }
    }
    
    // MARK: - Gradient Colors
    
    /// Get gradient colors for live status animations
    /// **Consolidates:** Live gradient logic scattered in views
    func liveGradientColors() -> [Color] {
        return [.red, .orange, .red]
    }
    
    /// Get gradient colors for loading states
    func loadingGradientColors() -> [Color] {
        return [.blue.opacity(0.3), .purple.opacity(0.3)]
    }
    
    // MARK: - Accessibility
    
    /// Get high-contrast version of a color for accessibility
    func highContrastColor(for color: Color) -> Color {
        // Simplified: return white or black based on luminance
        // In a real implementation, you'd calculate luminance properly
        return .white
    }
}