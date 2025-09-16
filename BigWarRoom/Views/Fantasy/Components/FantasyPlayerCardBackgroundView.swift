//
//  FantasyPlayerCardBackgroundView.swift
//  BigWarRoom
//
//  Background components for FantasyPlayerCard
//

import SwiftUI

/// Background jersey number component
struct FantasyPlayerCardBackgroundJerseyView: View {
    let jerseyNumber: String
    let teamColor: Color
    
    var body: some View {
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

/// Team gradient background component
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

/// Card background component
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

/// Card border component
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