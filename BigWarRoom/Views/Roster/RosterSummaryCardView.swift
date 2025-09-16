//
//  RosterSummaryCardView.swift
//  BigWarRoom
//
//  Summary card component displaying roster statistics
//

import SwiftUI

/// Component displaying roster statistics in a card format
struct RosterSummaryCardView: View {
    let filledSlots: Int
    let benchCount: Int
    let totalPlayers: Int
    let pickDisplayText: String
    
    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                value: "\(filledSlots)",
                label: "Starters",
                color: .primary
            )
            
            StatDivider()
            
            StatItem(
                value: "\(benchCount)",
                label: "Bench",
                color: .primary
            )
            
            StatDivider()
            
            StatItem(
                value: "\(totalPlayers)",
                label: "Total",
                color: .primary
            )
            
            StatDivider()
            
            StatItem(
                value: pickDisplayText,
                label: "Pick",
                color: .blue
            )
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Subcomponents
    
    private struct StatItem: View {
        let value: String
        let label: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private struct StatDivider: View {
        var body: some View {
            Divider()
                .frame(height: 30)
        }
    }
}