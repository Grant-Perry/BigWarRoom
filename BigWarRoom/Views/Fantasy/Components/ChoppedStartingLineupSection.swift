//
//  ChoppedStartingLineupSection.swift
//  BigWarRoom
//
//  🏈 CHOPPED STARTING LINEUP SECTION 🏈
//  Collapsible starting lineup section
//

import SwiftUI

/// **ChoppedStartingLineupSection**
/// 
/// Displays starting lineup players with collapsible functionality
struct ChoppedStartingLineupSection: View {
    let starters: [FantasyPlayer]
    let parentViewModel: ChoppedTeamRosterViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    @Binding var showStartingLineup: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showStartingLineup.toggle()
                }
            } label: {
                HStack {
                    Text("🔥 Starting Lineup")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(starters.count) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: showStartingLineup ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Collapsible Content - Use All Live Players cards
            if showStartingLineup {
                VStack(spacing: 8) {
                    ForEach(starters) { player in
                        // Use All Live Players design cards
                        ChoppedRosterPlayerCard(
                            player: player,
                            isStarter: true,
                            parentViewModel: parentViewModel,
                            onPlayerTap: onPlayerTap,
                            compact: true,
                            watchService: PlayerWatchService.shared
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20) // 🔥 IMPROVED: Better horizontal padding
        .padding(.vertical, 16)   // 🔥 IMPROVED: Better vertical padding
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    // Cannot preview without proper models setup
    Text("ChoppedStartingLineupSection Preview")
        .foregroundColor(.white)
        .background(Color.black)
}