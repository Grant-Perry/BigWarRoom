//
//  AllLivePlayersEmptyStateView.swift
//  BigWarRoom
//
//  Empty state view for All Live Players (handles both no leagues and no players scenarios)
//

import SwiftUI

/// Empty state handling both no leagues connected and no players for position
struct AllLivePlayersEmptyStateView: View {
    @ObservedObject var viewModel: AllLivePlayersViewModel
    let onAnimationReset: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            if viewModel.hasNoLeagues {
                noLeaguesView
            } else {
                noPlayersView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Leagues Connected View
    
    private var noLeaguesView: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                // Spinning football while trying to connect
                FantasyLoadingIndicator()
                    .scaleEffect(1.2)
                
                VStack(spacing: 8) {
                    Text("Connecting to Leagues...")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Searching for your connected leagues")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                // No connection established
                Image(systemName: "link.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("No Leagues Connected")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    Text("Connect to your leagues in Mission Control first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("NOTE: If connection cannot be established, re-connect your ESPN/Sleeper accounts in Mission Control.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Go to Mission Control button
                Button(action: {
                    // Send notification to switch to Mission Control tab
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.subheadline)
                        Text("Go to Mission Control")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    
    // MARK: - No Players for Position View
    
    private var noPlayersView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Active Players")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("No players found for \(viewModel.selectedPosition.displayName). Try selecting a different position or check if games are currently active.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 🔥 NEW: Recovery button for stuck filter states
            if viewModel.hasNoPlayersWithRecovery {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.recoverFromStuckState()
                        onAnimationReset()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.subheadline)
                        Text("Reset Filters")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            // Show some stats about connected leagues
            VStack(spacing: 8) {
                Text("✅ Connected: \(viewModel.connectedLeaguesCount) league\(viewModel.connectedLeaguesCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.green)
                
                if viewModel.selectedPosition != .all {
                    Button("Show All Positions") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.setPositionFilter(.all)
                            onAnimationReset()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.2))
            )
        }
    }
}

#Preview {
    AllLivePlayersEmptyStateView(
        viewModel: AllLivePlayersViewModel.shared,
        onAnimationReset: {}
    )
}