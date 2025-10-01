//
//  FantasyPlayerCardBackgroundView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Migrated to use UnifiedPlayerCardBackground
//  Legacy components maintained for backward compatibility
//

import SwiftUI

/// **Legacy wrapper for UnifiedPlayerCardBackground - Fantasy Style**
struct FantasyPlayerCardBackgroundJerseyView: View {
    let jerseyNumber: String
    let teamColor: Color
    
    var body: some View {
        // This is now handled by UnifiedPlayerCardBackground with jerseyNumber parameter
        // Keeping this as a simple fallback for any remaining references
        VStack {
            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    Text(jerseyNumber)
                        .font(.system(size: 90, weight: .black))
                        .italic()
                        .foregroundColor(teamColor)
                        .opacity(0.65)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                }
            }
            .padding(.trailing, 8)
            Spacer()
        }
    }
}

/// **Unified Fantasy Background Wrapper**
/// **Use this for new fantasy card implementations**
struct UnifiedFantasyPlayerCardBackground: View {
    let team: NFLTeam?
    let jerseyNumber: String?
    
    var body: some View {
        UnifiedPlayerCardBackground(
            configuration: .fantasy(
                team: team,
                jerseyNumber: jerseyNumber
            )
        )
    }
}

// MARK: - Legacy Components (Deprecated - Use UnifiedPlayerCardBackground instead)

/// Team gradient background component - DEPRECATED
struct FantasyPlayerCardTeamGradientView: View {
    let teamColor: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [teamColor, .clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

/// Card background component - DEPRECATED
struct FantasyPlayerCardBackgroundStyleView: View {
    let teamColor: Color
    let shadowColor: Color
    let shadowRadius: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(
                LinearGradient(
                    colors: [Color.black, teamColor.opacity(0.1), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: 0
            )
    }
}

/// Card border component - DEPRECATED
struct FantasyPlayerCardBorderView: View {
    let borderColors: [Color]
    let borderWidth: CGFloat
    let borderOpacity: Double
    let shadowColor: Color
    let shadowRadius: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .stroke(
                LinearGradient(
                    colors: borderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: borderWidth
            )
            .opacity(borderOpacity)
            .shadow(
                color: shadowColor,
                radius: shadowRadius * 0.5,
                x: 0,
                y: 0
            )
    }
}