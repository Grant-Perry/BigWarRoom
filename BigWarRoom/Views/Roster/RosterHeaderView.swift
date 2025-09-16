//
//  RosterHeaderView.swift
//  BigWarRoom
//
//  Header component for roster view showing draft context and status indicators
//

import SwiftUI

/// Header component displaying roster title, draft connection status, and turn indicator
struct RosterHeaderView: View {
    let title: String
    let subtitle: String
    let isLiveMode: Bool
    let isMyTurn: Bool
    let selectedDraft: SleeperLeague?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Draft status indicators
                VStack(spacing: 4) {
                    if isLiveMode && selectedDraft != nil {
                        liveDraftIndicator
                    }
                    
                    if isMyTurn {
                        yourTurnIndicator
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Status Indicators
    
    private var liveDraftIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("Live Draft")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
    }
    
    private var yourTurnIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
            Text("YOUR TURN")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.orange.opacity(0.2))
        .clipShape(Capsule())
    }
}