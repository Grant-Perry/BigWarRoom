//
//  ConflictAlertCard.swift
//  BigWarRoom
//
//  Alert card for player conflicts across leagues
//

import SwiftUI

/// Card displaying player conflict information and strategic recommendations
struct ConflictAlertCard: View {
    let conflict: ConflictPlayer
    
    var body: some View {
        HStack(spacing: 12) {
            // Player image (clickable)
            Button(action: {
                // TODO: Navigate to player stats page
                navigateToPlayerStats()
            }) {
                AsyncImage(url: conflict.player.headshotURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    // Fallback with player initials
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [conflict.severity.color, conflict.severity.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        Text(String(conflict.player.fullName.prefix(2)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(conflict.severity.color, lineWidth: 2)
                )
                
                // Severity badge
                VStack(spacing: 2) {
                    Spacer()
                    Text(conflict.severity.rawValue)
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(conflict.severity.color)
                        )
                        .offset(y: 6)
                }
                .frame(width: 50, height: 50)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 60)
            
            // Player and conflict info
            VStack(alignment: .leading, spacing: 6) {
                // Player name and position
                HStack {
                    Text(conflict.player.fullName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(conflict.player.position)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(positionColor.opacity(0.3))
                        )
                    
                    Spacer()
                    
                    // Net impact indicator
                    HStack(spacing: 2) {
                        Image(systemName: conflict.netImpact >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text(conflict.netImpact.formatted(.number.precision(.fractionLength(1))))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(conflict.netImpact >= 0 ? .green : .red)
                }
                
                // League breakdown
                HStack(spacing: 8) {
                    // My leagues
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOU OWN:")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.green)
                        
                        ForEach(conflict.myLeagues.prefix(2)) { league in
                            Text(league.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    
                    Text("VS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.gray)
                    
                    // Opponent leagues
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FACING:")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.red)
                        
                        ForEach(conflict.opponentLeagues.prefix(2)) { league in
                            Text(league.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            // Blur backdrop layer
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial) // iOS blur material
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.2)) // Light tint for transparency
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(conflict.severity.color.opacity(0.6), lineWidth: 1)
                )
        )
        .background(
            // Outer glow effect
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            conflict.severity.color.opacity(0.15),
                            conflict.severity.color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 1)
        )
    }
    
    // MARK: - Helper Properties
    
    private var positionColor: Color {
        switch conflict.player.position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
    
    // MARK: - Navigation Actions
    
    private func navigateToPlayerStats() {
        // TODO: Implement navigation to player stats page
        // This could use NavigationLink or a coordinator pattern
        print("🏃‍♂️ Navigate to \(conflict.player.fullName) stats page")
    }
}