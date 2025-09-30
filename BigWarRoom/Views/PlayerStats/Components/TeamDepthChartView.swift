//
//  TeamDepthChartView.swift
//  BigWarRoom
//
//  Team depth chart section for PlayerStatsCardView
//

import SwiftUI

/// Team depth chart display using organized position data
struct TeamDepthChartView: View {
    let depthChartData: [String: DepthChartData]
    let team: NFLTeam?
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    @State private var isExpanded: Bool = true // Changed to false for initial minimized state

    // 🏈 PLAYER NAVIGATION: Remove sheet states, use NavigationLink instead
    // BEFORE: Used sheet presentation which failed for nested sheets
    // AFTER: Use NavigationLink for proper nested navigation
    
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
                        Image(systemName: "person.3.fill")
                            .font(.caption)
                            .foregroundColor(.gpBlue)
                        
                        Text("Team Depth Chart")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if let team = team {
                            HStack(spacing: 4) {
                                teamAssets.logoOrFallback(for: team.id)
                                    .frame(width: 16, height: 16)
                                
                                Text(team.name)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Collapsible Content
            if isExpanded {
                if depthChartData.isEmpty {
                    emptyStateView
                } else {
                    depthChartContent
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(overlayBorder)
        .shadow(color: (team?.primaryColor ?? Color.gpBlue).opacity(0.2), radius: 4, x: 0, y: 2)
        // 🏈 PLAYER NAVIGATION: Remove sheet - using NavigationLinks instead
    }
    
    // MARK: - Content Views
    
    private var depthChartContent: some View {
        LazyVStack(spacing: 6) {
            ForEach(["QB", "RB", "WR", "TE", "K", "DEF"], id: \.self) { position in
                if let positionData = depthChartData[position], !positionData.players.isEmpty {
                    PositionGroupView(
                        positionData: positionData,
                        team: team
                        // 🏈 PLAYER NAVIGATION: Remove tap handler - using NavigationLinks instead
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No depth chart data available")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
    
    // 🏈 PLAYER NAVIGATION: Remove tap handler - no longer needed
    
    // MARK: - Background and Styling (Same as Live Game Stats)
    
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

/// Position group within depth chart
private struct PositionGroupView: View {
    let positionData: DepthChartData
    let team: NFLTeam?
    // 🏈 PLAYER NAVIGATION: Remove tap handler parameter - using NavigationLinks instead
    
    @State private var isExpanded: Bool = true // Changed to true for initial expanded state
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Collapsible Position header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(positionData.position)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(positionData.positionColor)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(positionData.players.count) players")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            
            // Collapsible Players in this position
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(positionData.players, id: \.player.playerID) { depthPlayer in
                        DepthChartPlayerRowView(
                            depthPlayer: depthPlayer,
                            team: team,
                            onTap: nil // 🏈 PLAYER NAVIGATION: Remove tap handler - using NavigationLinks instead
                        )
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
