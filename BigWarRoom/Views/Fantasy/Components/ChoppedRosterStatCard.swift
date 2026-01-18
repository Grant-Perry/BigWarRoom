//
//  ChoppedRosterStatCard.swift
//  BigWarRoom
//
//  🏈 CHOPPED ROSTER STAT CARD 🏈
//  Individual stat card component
//

import SwiftUI

/// **ChoppedRosterStatCard**
/// 
/// Displays a single stat card with title, value, and color
struct ChoppedRosterStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}