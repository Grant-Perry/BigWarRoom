//
//  EmptyRosterSlotView.swift
//  BigWarRoom
//
//  Component for displaying empty roster slot placeholders
//

import SwiftUI

/// Component for displaying empty roster slot with position label
struct EmptyRosterSlotView: View {
    let position: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Empty slot placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(position.prefix(3))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                )
            
            // Empty slot description
            VStack(alignment: .leading, spacing: 4) {
                Text("Empty \(position) slot")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text("No player assigned")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(emptySlotBackground)
    }
    
    // MARK: - Background Styling
    
    private var emptySlotBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            )
    }
}