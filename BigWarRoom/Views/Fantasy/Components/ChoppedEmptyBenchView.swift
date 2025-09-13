//
//  ChoppedEmptyBenchView.swift
//  BigWarRoom
//
//  🏈 CHOPPED EMPTY BENCH VIEW 🏈
//  Displays when no bench players are present
//

import SwiftUI

/// **ChoppedEmptyBenchView**
/// 
/// Displays message when bench is empty
struct ChoppedEmptyBenchView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No bench players")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("All roster spots are filled with starters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ChoppedEmptyBenchView()
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}