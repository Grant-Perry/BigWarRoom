//
//  PlayerScoreBarCardLeagueBannerView.swift
//  BigWarRoom
//
//  League banner component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardLeagueBannerView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    var body: some View {
        HStack(spacing: 4) {
            // 🔥 DEBUG: Add logging to see actual leagueSource values
            Group {
                let leagueSourceValue = playerEntry.leagueSource
//                let _ = print("🔍 DEBUG - League source: '\(leagueSourceValue)' (lowercased: '\(leagueSourceValue.lowercased())') for league: '\(playerEntry.leagueName)'")
                
                switch leagueSourceValue.lowercased() {
                case "espn":
                    Image("espnLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)  // 50% smaller (was 24x24)
                case "sleeper":
                    Image("sleeperLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)  // 50% smaller (was 24x24)
                default:
                    // 🔥 DEBUG: Log when falling back to circle
                    let _ = print("❌ FALLBACK - Unknown league source: '\(leagueSourceValue)' - using circle fallback")
                    Circle()
                        .fill(leagueSourceColor)
                        .frame(width: 6, height: 6)
                }
            }
            
            Text(playerEntry.leagueName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(leagueSourceColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var leagueSourceColor: Color {
        switch playerEntry.leagueSource {
        case "Sleeper": return .blue
        case "ESPN": return .red
        default: return .gray
        }
    }
}
