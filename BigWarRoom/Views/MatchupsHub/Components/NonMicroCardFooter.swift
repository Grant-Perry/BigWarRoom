//
//  NonMicroCardFooter.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Footer component for non-micro cards
struct NonMicroCardFooter: View {
    let matchup: UnifiedMatchup
    let dualViewMode: Bool
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        HStack {
            // Time ago
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                
                Text(timeAgo(matchup.lastUpdated))
                    .font(.system(size: dualViewMode ? 9 : 8, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Score differential - if available
            if let differential = matchup.scoreDifferential {
                Text(differential > 0 ? "+\(String(format: "%.1f", differential))" : String(format: "%.1f", differential))
                    .font(.system(size: dualViewMode ? 9 : 8, weight: .bold, design: .monospaced))
                    .foregroundColor(differential > 0 ? .green : .red)
            }
            
            Spacer()
            
            // Tap hint
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray.opacity(0.6))
        }
    }
}