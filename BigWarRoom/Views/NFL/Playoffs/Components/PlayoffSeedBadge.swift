//
//  PlayoffSeedBadge.swift
//  BigWarRoom
//
//  Seed badge display for playoff teams
//

import SwiftUI

struct PlayoffSeedBadge: View {
    let seed: Int
    
    var body: some View {
        Text("\(seed)")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(
                Circle()
                    .fill(seedColor)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
    }
    
    /// Color coding for playoff seeds (gold/silver/bronze for top 3)
    private var seedColor: Color {
        switch seed {
        case 1:
            return Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
        case 2:
            return Color(red: 0.75, green: 0.75, blue: 0.75)  // Silver
        case 3:
            return Color(red: 0.8, green: 0.5, blue: 0.2)  // Bronze
        default:
            return .blue
        }
    }
}