//
//  AIPickSuggestionsHeaderView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Updated to use reusable header components
//  Uses UnifiedStatusBadge and UnifiedHeaderBackground for DRY compliance
//

import SwiftUI

/// AI header section with strategy engine info and draft context
/// **Now using reusable header components**
struct AIPickSuggestionsHeaderView: View {
    let viewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("AI Strategy Engine")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Smart pick recommendations based on your draft context")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.isLiveMode {
                    VStack(spacing: 4) {
                        // 🔥 REFACTOR: Using UnifiedStatusBadge
                        UnifiedStatusBadge(
                            configuration: .liveStatus(count: viewModel.suggestions.count)
                        )
                        
                        Text("\(viewModel.suggestions.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        
                        Text("suggestions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Draft context info (if connected)
            if let selectedDraft = viewModel.selectedDraft {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Draft Context")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedDraft.name)
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if let myRosterID = viewModel.myRosterID {
                        // 🔥 REFACTOR: Using UnifiedStatusBadge
                        UnifiedStatusBadge(
                            configuration: StatusBadgeConfiguration(
                                text: "Pick \(myRosterID)",
                                color: .blue,
                                font: .callout,
                                fontWeight: .bold
                            )
                        )
                    }
                    
                    if viewModel.isMyTurn {
                        // 🔥 REFACTOR: Using UnifiedStatusBadge
                        UnifiedStatusBadge(
                            configuration: .yourTurn()
                        )
                    }
                }
            }
        }
        .padding()
        // 🔥 REFACTOR: Using UnifiedHeaderBackground
        .background(
            UnifiedHeaderBackground(style: .dramatic(.purple, 16))
        )
    }
}