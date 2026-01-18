//
//  GameAlertCard.swift
//  BigWarRoom
//
//  Card component for displaying game alerts (highest scoring plays per refresh)
//

import SwiftUI

/// Card for displaying a single game alert
struct GameAlertCard: View {
    let alert: GameAlert
    
    var body: some View {
        HStack(spacing: 12) {
            // Player position badge
            playerPositionBadge
            
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Player name and points
                HStack(spacing: 8) {
                    Text(alert.playerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Points gained
                    Text("+\(alert.pointsDisplay)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gpGreen)
                }
                
                // League and time info
                HStack(spacing: 8) {
                    Text(alert.leagueName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text(alert.timeAgoDisplay)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Alert icon
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.gpOrange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(alert.teamColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var playerPositionBadge: some View {
        Text(alert.playerPosition)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 32, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(alert.teamColor)
            )
    }
}