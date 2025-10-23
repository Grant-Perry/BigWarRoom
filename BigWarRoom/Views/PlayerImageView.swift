//
//  PlayerImageView.swift
//  BigWarRoom
//
//  Smart player image loader with multiple fallback sources
//
// MARK: -> Player Image View

import SwiftUI

struct PlayerImageView: View {
    let player: SleeperPlayer
    let size: CGFloat
    let team: NFLTeam?
    
    var body: some View {
        ZStack {
            AsyncImage(url: player.headshotURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    // Show team-colored fallback with player initials
                    Circle()
                        .fill(team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            Text(player.firstName?.prefix(1).uppercased() ?? "?")
                                .font(.system(size: size * 0.4, weight: .bold))
                                .foregroundColor(team?.accentColor ?? .white)
                        )
                @unknown default:
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(team?.primaryColor.opacity(0.3) ?? Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // 🔥 NEW: Injury Status Badge (positioned at bottom-right)
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .scaleEffect(badgeScale) // Scale based on image size
                            .offset(x: badgeOffset, y: badgeOffset) // Position as subscript
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Scale badge based on image size
    private var badgeScale: CGFloat {
        switch size {
        case 0..<40: return 0.7
        case 40..<60: return 0.8
        case 60..<80: return 0.9
        default: return 1.0
        }
    }
    
    /// Offset badge based on image size
    private var badgeOffset: CGFloat {
        switch size {
        case 0..<40: return -3
        case 40..<60: return -4
        case 60..<80: return -6
        default: return -8
        }
    }
}