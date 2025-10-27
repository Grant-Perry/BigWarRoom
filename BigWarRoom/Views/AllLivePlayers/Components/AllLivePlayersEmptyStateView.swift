//
//  AllLivePlayersEmptyStateView.swift
//  BigWarRoom
//
//  Empty state view for when no players match current filters
//

import SwiftUI

/// Shows appropriate empty state based on current filter conditions
struct AllLivePlayersEmptyStateView: View {
    @Bindable var allLivePlayersViewModel: AllLivePlayersViewModel
    let onAnimationReset: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon and title based on state
            Group {
                if allLivePlayersViewModel.hasNoLeagues {
                    // No leagues connected at all
                    AllLivePlayersNoLeaguesView(allLivePlayersViewModel: allLivePlayersViewModel)
                } else {
                    // Has leagues but no players matching filters
                    noPlayersContent
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noPlayersContent: some View {
        VStack(spacing: 24) {
            // 🔥 NEW: Different messaging for Active Only vs other filters
            if allLivePlayersViewModel.showActiveOnly {
                activeOnlyEmptyState
            } else {
                standardEmptyState
            }
        }
    }
    
    private var activeOnlyEmptyState: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            // Title
            Text("No Active Players")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // 🔥 NEW: Better messaging for Active Only filter
            VStack(spacing: 12) {
                Text("No players found for \(allLivePlayersViewModel.selectedPosition.displayName). Try selecting a different position or check if games are currently active.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // 🔥 NEW: Show game status info
                if NFLGameDataService.shared.gameData.isEmpty {
                    Text("🔄 Loading game data...")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    let liveGameCount = NFLGameDataService.shared.gameData.values.filter { $0.isLive }.count / 2 // Divide by 2 since each game has 2 teams
                    if liveGameCount > 0 {
                        Text("📡 \(liveGameCount) games currently live")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("⏰ No games currently live")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Reset Filters button
            Button(action: {
                allLivePlayersViewModel.setShowActiveOnly(false)
                allLivePlayersViewModel.setPositionFilter(.all)
                onAnimationReset()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Reset Filters")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.orange)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var standardEmptyState: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            // Title
            Text("No Active Players")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Description
            Text("No players found for \(allLivePlayersViewModel.selectedPosition.displayName). Try selecting a different position or check if games are currently active.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Reset Filters button
            Button(action: {
                allLivePlayersViewModel.setPositionFilter(.all)
                onAnimationReset()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Reset Filters")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.orange)
                )
            }
            .buttonStyle(.plain)
        }
    }
}