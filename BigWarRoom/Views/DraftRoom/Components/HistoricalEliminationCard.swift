//
//  HistoricalEliminationCard.swift
//  BigWarRoom
//
//  💀⚰️ HISTORICAL ELIMINATION CARD ⚰️💀
//  The Graveyard - Chronicle of the Fallen
//

import SwiftUI

/// **HistoricalEliminationCard**
/// 
/// Memorial card for historical eliminations featuring:
/// - Week tombstone marker
/// - Elimination details and final score
/// - Last words if available
/// - Drama meter indicator with broken hearts
/// - Margin display and elimination score
struct HistoricalEliminationCard: View {
    let elimination: EliminationEvent
    
    var body: some View {
        HStack(spacing: 16) {
            // Week tombstone
            VStack {
                Text("⚰️")
                    .font(.system(size: 24))
                
                Text("WK \(elimination.week)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
                    .tracking(1)
            }
            .frame(width: 50)
            
            // Eliminated team info - FIXED NO WRAP
            VStack(alignment: .leading, spacing: 4) {
                Text(elimination.eliminatedTeam.team.ownerName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .strikethrough()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("💀 ELIMINATED WEEK \(elimination.week)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let lastWords = elimination.lastWords {
                    Text("\"\(lastWords)\"")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Text("Margin: \(elimination.marginDisplay) • \(elimination.dramaMeterDisplay)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Final score and elimination details
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", elimination.eliminationScore))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                
                Text("FINAL")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                // Drama indicator
                dramaMeterIndicator
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Computed Properties
    
    private var dramaMeterIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<Int(elimination.dramaMeter * 5), id: \.self) { _ in
                Text("💔")
                    .font(.system(size: 8))
            }
        }
    }
}