//
//  AllLivePlayersNoPlayersView.swift
//  BigWarRoom
//
//  No players for position component for AllLivePlayersEmptyStateView
//

import SwiftUI

/// No players for position view component
struct AllLivePlayersNoPlayersView: View {
    let viewModel: AllLivePlayersViewModel
    let onAnimationReset: () -> Void
    
    var body: some View {
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