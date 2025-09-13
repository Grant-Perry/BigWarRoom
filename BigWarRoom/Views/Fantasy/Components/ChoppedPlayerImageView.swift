//
//  ChoppedPlayerImageView.swift
//  BigWarRoom
//
//  🏈 CHOPPED PLAYER IMAGE VIEW 🏈
//  Player image with fallback logic
//

import SwiftUI

/// **ChoppedPlayerImageView**
/// 
/// Displays player image with team-colored fallback
struct ChoppedPlayerImageView: View {
    let viewModel: ChoppedPlayerCardViewModel
    
    var body: some View {
        Group {
            if let sleeperPlayer = viewModel.sleeperPlayer {
                PlayerImageView(
                    player: sleeperPlayer,
                    size: 100,
                    team: viewModel.nflTeam
                )
                .offset(x: -25, y: 1)
            } else {
                // Fallback with team colors
                Circle()
                    .fill(viewModel.teamGradient)
                    .overlay(
                        Text(String(viewModel.player.firstName?.prefix(1) ?? ""))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .frame(width: 60, height: 60)
            }
        }
    }
}

#Preview {
    // Cannot preview without proper ViewModel setup
    Text("ChoppedPlayerImageView Preview")
        .foregroundColor(.white)
        .background(Color.black)
}