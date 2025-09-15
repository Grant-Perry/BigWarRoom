//
//  PlayerLiveStatsView.swift
//  BigWarRoom
//
//  Live stats section with position-specific displays
//

import SwiftUI

/// Live stats section with position-specific stat displays
struct PlayerLiveStatsView: View {
    let playerStatsData: PlayerStatsData?
    let team: NFLTeam?
    let isLoading: Bool
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.gpBlue)
                        
                        Text("Live Game Stats")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Week indicator
                        Text("Week \(NFLWeekService.shared.currentWeek)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(colors: [.gpBlue, .gpGreen], startPoint: .leading, endPoint: .trailing))
                            )
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Collapsible Content
            if isExpanded {
                Group {
                    if isLoading {
                        loadingView
                    } else if let statsData = playerStatsData, statsData.hasStats {
                        statsContent(for: statsData)
                    } else {
                        noStatsView
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(overlayBorder)
        .shadow(color: (team?.primaryColor ?? Color.gpBlue).opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Content Views
    
    private func statsContent(for data: PlayerStatsData) -> some View {
        VStack(spacing: 6) {
            // Fantasy Points Row (Always shown if available)
            if data.pprPoints > 0 {
                fantasyPointsRow(data: data)
            }
            
            // Position-specific stats
            PositionStatsGridView(statsData: data)
        }
    }
    
    private func fantasyPointsRow(data: PlayerStatsData) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("Fantasy Points")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // PPR Points (main)
                StatBubbleView(
                    value: String(format: "%.1f", data.pprPoints),
                    label: "PPR PTS",
                    color: .gpGreen,
                    isLarge: false
                )
                
                // Half PPR if different
                if data.halfPprPoints != data.pprPoints {
                    StatBubbleView(
                        value: String(format: "%.1f", data.halfPprPoints),
                        label: "HALF PPR",
                        color: .gpBlue
                    )
                }
                
                // Standard if different
                if data.standardPoints != data.pprPoints {
                    StatBubbleView(
                        value: String(format: "%.1f", data.standardPoints),
                        label: "STANDARD",
                        color: .orange
                    )
                }
                
                Spacer()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            
            Text("Loading live stats...")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
    
    private var noStatsView: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No live stats available")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
            
            Text("Player may not be in an active game this week")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Background and Styling
    
    private var backgroundView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    team?.primaryColor.opacity(0.6) ?? Color.gpBlue.opacity(0.6),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle pattern overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1),
                    Color.clear,
                    Color.white.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var overlayBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                LinearGradient(
                    colors: [Color.gpBlue, team?.accentColor ?? Color.gpGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}

#Preview {
    PlayerLiveStatsView(
        playerStatsData: nil,
        team: nil,
        isLoading: false
    )
}