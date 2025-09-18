//
//  ScoreBreakdownView.swift
//  BigWarRoom
//
//  Score breakdown popup view for fantasy players
//

import SwiftUI

/// Score breakdown popup view that displays detailed fantasy scoring
struct ScoreBreakdownView: View {
    let breakdown: PlayerScoreBreakdown
    @Environment(\.dismiss) private var dismiss
    
    // Get team color for gradient styling
    private var teamColor: Color {
        if let team = breakdown.player.team {
            return NFLTeamColors.color(for: team)
        }
        return .blue
    }
    
    // Create gradient background like Live Game Stats
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                teamColor.opacity(0.8),
                teamColor.opacity(0.6),
                Color.black.opacity(0.7),
                Color(red: 0.15, green: 0.18, blue: 0.25).opacity(0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Create gradient border
    private var borderGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                teamColor.opacity(0.9),
                teamColor.opacity(0.7),
                Color.white.opacity(0.3),
                teamColor.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            // Dark background overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Main content card with team color gradient
            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // 🔥 FIXED: Add ScrollView around stats section
                if breakdown.hasStats {
                    ScrollView(.vertical, showsIndicators: true) {
                        statsTableSection
                    }
                    .frame(maxHeight: 400) // Limit height so total is always visible
                } else {
                    noStatsSection
                }
                
                // Total section - ALWAYS VISIBLE at bottom
                totalSection
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderGradient, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 24)
            .shadow(color: teamColor.opacity(0.3), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 8)
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        Circle()
                                            .stroke(borderGradient, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.trailing, 32)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Player name
            Text(breakdown.playerDisplayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            // Week info
            Text(breakdown.weekDisplayString)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.2))
        )
    }
    
    private var statsTableSection: some View {
        VStack(spacing: 0) {
            // Table header - Show different headers for Chopped vs Regular leagues
            tableHeaderRow
            
            // Divider
            Rectangle()
                .fill(teamColor.opacity(0.6))
                .frame(height: 2)
            
            // Stats rows
            ForEach(breakdown.items) { item in
                statsRow(item: item)
                
                // Divider between rows (except last)
                if item.id != breakdown.items.last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var tableHeaderRow: some View {
        HStack(spacing: 8) {
            Text("STAT")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("QTY")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, alignment: .center)
            
            // 🔥 FIXED: Show PTS PER and POINTS columns when we have REAL scoring data (chopped OR ESPN)
            if breakdown.hasRealScoringData {
                Text("PTS PER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .center)
                
                Text("POINTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
    }
    
    private func statsRow(item: ScoreBreakdownItem) -> some View {
        HStack(spacing: 8) {
            Text(item.statName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // QTY column - shows the stat value
            Text(item.statValueString)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, alignment: .center)
            
            // 🔥 FIXED: Show PTS PER and POINTS for leagues with REAL scoring data (chopped OR ESPN)
            if breakdown.hasRealScoringData {
                Text(item.pointsPerStatString)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .center)
                
                Text(item.totalPointsString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
    }
    
    private var totalSection: some View {
        VStack(spacing: 0) {
            // Divider with team color
            Rectangle()
                .fill(teamColor.opacity(0.8))
                .frame(height: 3)
            
            // Total row
            HStack(spacing: 8) {
                Text("Fantasy Points")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 🔥 FIXED: Alignment based on whether we have real scoring data
                Text(breakdown.totalScoreString)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: breakdown.hasRealScoringData ? 70 : 60, alignment: breakdown.hasRealScoringData ? .trailing : .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    teamColor.opacity(0.1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var noStatsSection: some View {
        VStack(spacing: 12) {
            Text("No stats available")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("This player hasn't recorded any stats yet this week")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}