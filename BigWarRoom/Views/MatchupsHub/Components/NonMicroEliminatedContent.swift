//
//  NonMicroEliminatedContent.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Eliminated card content for non-micro cards
struct NonMicroEliminatedContent: View {
    let matchup: UnifiedMatchup
    let dualViewMode: Bool
    let eliminatedPulse: Bool
    
    private var myEliminationWeek: Int? {
        return matchup.myEliminationWeek
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        VStack(spacing: dualViewMode ? 6 : 3) {
            // Header with league info (full league name)
            HStack {
                // League name with platform logo - FULL WIDTH
                HStack(spacing: 6) {
                    Group {
                        switch matchup.league.source {
                        case .espn:
                            AppConstants.espnLogo
                                .scaleEffect(0.4)
                        case .sleeper:
                            AppConstants.sleeperLogo
                                .scaleEffect(0.4)
                        }
                    }
                    .frame(width: 16, height: 16)
                    
                    Text("\(matchup.league.league.name)")
                        .font(.system(size: dualViewMode ? 18 : 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer()
            }
            
            // CHOPPED badge - second row
            HStack {
                if matchup.isChoppedLeague {
                    Text("🔥 CHOPPED")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.2))
                        )
                }
                
                Spacer()
            }
            
            // Main eliminated content - COMPACT
            VStack(spacing: 2) {
                // ELIMINATED text without skulls (fits one line)
                Text("ELIMINATED")
                    .font(.system(size: dualViewMode ? 16 : 14, weight: .black))
                    .foregroundColor(.white)
                    .tracking(1.5)
                
                // Skulls on separate line - SMALLER
                HStack(spacing: 4) {
                    Text("💀")
                        .font(.system(size: dualViewMode ? 18 : 16))
                        .scaleEffect(eliminatedPulse ? 1.1 : 1.0)
                    
                    Text("☠️")
                        .font(.system(size: dualViewMode ? 18 : 16))
                        .scaleEffect(eliminatedPulse ? 1.1 : 1.0)
                }
                
                // Week and manager info - COMPACT
                if let week = myEliminationWeek {
                    Text("Week \(week)")
                        .font(.system(size: dualViewMode ? 12 : 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Manager name (if available) - COMPACT
                if let myTeam = matchup.myTeam {
                    Text(myTeam.ownerName)
                        .font(.system(size: dualViewMode ? 11 : 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer() // Add spacer to push content up and fill height consistently
            
            // Footer - just time (NO SPACER!) - COMPACT
            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    
                    Text(timeAgo(matchup.lastUpdated))
                        .font(.system(size: dualViewMode ? 9 : 8, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Tap hint
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top) // 🔥 FIXED: Fill available height, align content to top
        .padding(.horizontal, 12)
        .padding(.vertical, dualViewMode ? 14 : 8)
        .background(NonMicroEliminatedBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.red, .black, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.0
                )
        )
        .frame(height: dualViewMode ? 150 : 120)
    }
}