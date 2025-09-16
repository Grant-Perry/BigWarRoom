//
//  LeaguePickerOverlayHeaderView.swift
//  BigWarRoom
//
//  Header component for LeaguePickerOverlay
//

import SwiftUI

/// Header view for league picker overlay
struct LeaguePickerOverlayHeaderView: View {
    let leagues: [UnifiedMatchup]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.gpGreen, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Choose Your League")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Text("Select a league to view detailed matchups")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                }
            }
            
            // Stats summary
            HStack(spacing: 20) {
                StatPill(
                    icon: "building.2.fill",
                    title: "Leagues",
                    value: "\(leagues.count)",
                    color: .blue
                )
                
                StatPill(
                    icon: "person.2.fill",
                    title: "Active",
                    value: "\(leagues.filter { !$0.isChoppedLeague }.count)",
                    color: .gpGreen
                )
                
                StatPill(
                    icon: "chart.bar.fill",
                    title: "Chopped",
                    value: "\(leagues.filter { $0.isChoppedLeague }.count)",
                    color: .purple
                )
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

/// Stat pill component
struct StatPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}