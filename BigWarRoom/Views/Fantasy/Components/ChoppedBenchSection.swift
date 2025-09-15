//
//  ChoppedBenchSection.swift
//  BigWarRoom
//
//  🏈 CHOPPED BENCH SECTION 🏈
//  Collapsible bench section
//

import SwiftUI

/// **ChoppedBenchSection**
/// 
/// Displays bench players with collapsible functionality
struct ChoppedBenchSection: View {
    let bench: [FantasyPlayer]
    let parentViewModel: ChoppedTeamRosterViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    @Binding var showBench: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showBench.toggle()
                }
            } label: {
                HStack {
                    Text("🪑 Bench")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(bench.count) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: showBench ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Collapsible Content
            if showBench {
                if bench.isEmpty {
                    ChoppedEmptyBenchView()
                } else {
                    VStack(spacing: 12) {
                        ForEach(bench) { player in
                            ChoppedRosterPlayerCard(
                                player: player,
                                isStarter: false,
                                parentViewModel: parentViewModel,
                                onPlayerTap: onPlayerTap,
                                compact: true
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    // Cannot preview without proper models setup
    Text("ChoppedBenchSection Preview")
        .foregroundColor(.white)
        .background(Color.black)
}