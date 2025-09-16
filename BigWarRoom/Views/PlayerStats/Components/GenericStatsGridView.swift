//
//  GenericStatsGridView.swift
//  BigWarRoom
//
//  Generic fallback stats component for PositionStatsGridView - CLEAN ARCHITECTURE
//

import SwiftUI

struct GenericStatsGridView: View {
    let statsData: PlayerStatsData
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Limited stats available")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}