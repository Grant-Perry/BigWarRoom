//
//  NFLTeamRosterView.swift
//  BigWarRoom
//
//  🏈 NFL TEAM ROSTER VIEW 🏈
//  Full NFL team roster display with smart filtering
//

import SwiftUI

/// **NFLTeamRosterView**
/// 
/// Shows a complete NFL team roster with:
/// - Smart filtering: hides 0.0 point players in completed games  
/// - Position priority sorting: QB, RB, WR, TE, K, DST
/// - Beautiful player cards with stats and game status
/// - Player tap navigation to detailed stats
struct NFLTeamRosterView: View {
    let teamCode: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NFLTeamRosterViewModel
    
    // MARK: - Initialization
    
    init(teamCode: String) {
        self.teamCode = teamCode
        self.viewModel = NFLTeamRosterViewModel(
            teamCode: teamCode,
            coordinator: TeamRosterCoordinator(livePlayersViewModel: AllLivePlayersViewModel.shared),
            nflGameService: NFLGameDataService.shared
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.filteredPlayers.isEmpty {
                    rosterContentView
                } else {
                    errorView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadTeamRoster()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            TeamLogoView(teamCode: teamCode, size: 80)
                .clipShape(Circle())
            
            Text("Loading \(getTeamName()) Roster...")
                .font(.title3)
                .foregroundColor(.white)
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }
    }
    
    // MARK: - Roster Content View
    
    private var rosterContentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Team header
                teamHeaderCard
                    .padding(.horizontal, 16)
                
                // Players list
                playersListView
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Team Header Card
    
    private var teamHeaderCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Team logo
                TeamLogoView(teamCode: teamCode, size: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(viewModel.teamInfo?.primaryColor ?? Color.white, lineWidth: 3)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.teamInfo?.teamName ?? teamCode)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Active Roster")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Player count with filtering info
                    HStack(spacing: 16) {
                        Text("\(viewModel.filteredPlayers.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.teamInfo?.primaryColor ?? .white)
                        
                        Text("CONTRIBUTING PLAYERS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            viewModel.teamInfo?.primaryColor.opacity(0.2) ?? Color.white.opacity(0.1),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(viewModel.teamInfo?.primaryColor.opacity(0.3) ?? Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Players List View
    
    private var playersListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header
            HStack {
                Text("🏈 Contributing Players")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Sorted by position & points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            
            // Players
            VStack(spacing: 8) {
                ForEach(viewModel.filteredPlayers, id: \.playerID) { player in
                    NFLPlayerCard(
                        player: player,
                        viewModel: viewModel,
                        onPlayerTap: nil
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(getTeamColor().opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(getTeamColor().opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 20) {
            TeamLogoView(teamCode: teamCode, size: 80)
                .clipShape(Circle())
                .opacity(0.5)
            
            Text("No Contributing Players")
                .font(.title3)
                .foregroundColor(.white)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            } else {
                Text("All players with 0.0 points have been filtered out from this completed game")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button("Try Again") {
                Task {
                    await viewModel.loadTeamRoster()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getTeamName() -> String {
        return NFLTeam.team(for: teamCode)?.city ?? teamCode
    }
    
    private func getTeamColor() -> Color {
        return TeamAssetManager.shared.team(for: teamCode)?.primaryColor ?? Color.white
    }
}

// MARK: - NFL Player Card Component

struct NFLPlayerCard: View {
    let player: SleeperPlayer
    let viewModel: NFLTeamRosterViewModel
    let onPlayerTap: ((SleeperPlayer) -> Void)?
    
    var body: some View {
        NavigationLink(
            destination: PlayerStatsCardView(
                player: player,
                team: NFLTeam.team(for: player.team ?? "")
            )
        ) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardContent: some View {
        HStack(spacing: 16) {
            // Player image/position indicator
            ZStack {
                Circle()
                    .fill(getPositionColor(player.position ?? "").opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(getPositionColor(player.position ?? ""), lineWidth: 2)
                    )
                
                Text(player.position ?? "?")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(getPositionColor(player.position ?? ""))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Player name
                Text("\(player.firstName ?? "") \(player.lastName ?? "")")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Stats breakdown
                if let breakdown = viewModel.formatPlayerStatBreakdown(player), !breakdown.isEmpty {
                    Text(breakdown)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Points
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", viewModel.getPlayerPoints(for: player) ?? 0.0))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(getPointsColor())
                
                Text("pts")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func getPositionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DST", "DEF": return .red
        default: return .gray
        }
    }
    
    private func getPointsColor() -> Color {
        let points = viewModel.getPlayerPoints(for: player) ?? 0.0
        if points > 10 { return .gpGreen }
        if points > 5 { return .white }
        return .secondary
    }
}

#Preview("NFL Team Roster") {
    NavigationView {
        NFLTeamRosterView(teamCode: "KC")
            .preferredColorScheme(.dark)
    }
}