//
//  EmptyBenchView.swift
//  BigWarRoom
//
//  Component for displaying empty bench state
//

import SwiftUI

/// Component for displaying empty bench with helpful messaging
struct EmptyBenchView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.title3)
                .foregroundColor(.secondary)
                
            VStack(alignment: .leading, spacing: 4) {
                Text("No bench players")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Add players to your bench as the draft progresses")
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