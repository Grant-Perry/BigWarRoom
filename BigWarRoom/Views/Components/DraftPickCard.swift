//
//  DraftPickCard.swift
//  BigWarRoom
//
//  Individual draft pick card for live draft feed
//
// MARK: -> Draft Pick Card

import SwiftUI

struct DraftPickCard: View {
    let pick: EnhancedPick
    let isRecent: Bool // Highlight recent picks
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Compact header: Pick number, position, and positional rank
            HStack(spacing: 6) {
                // Pick number (smaller)
                Text(pick.pickDescription)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Positional rank badge (RB1, WR2, etc.) - NEW
                if let positionRank = pick.player.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                
                // Position badge
                Text(pick.position)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(positionColor(pick.position))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Player section: smaller image + prominent name + fantasy rank
            HStack(spacing: 6) {
                // Smaller player image
                PlayerImageView(
                    player: pick.player,
                    size: 32,
                    team: pick.team
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    // Prominent player name with scaling
                    Text(pick.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    // Fantasy rank (if available)
                    if let searchRank = pick.player.searchRank {
                        Text("FR: \(searchRank)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    
                    // Team info with logo
                    HStack(spacing: 2) {
                        TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                            .frame(width: 10, height: 10)
                        
                        Text(pick.teamCode)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isRecent ? Color.blue.opacity(0.15) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecent ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .frame(width: 125, height: 110)
        .scaleEffect(isRecent ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isRecent)
    }
    
    private func positionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .purple
        case "RB": return .green
        case "WR": return .blue
        case "TE": return .orange
        case "K": return .gray
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
}