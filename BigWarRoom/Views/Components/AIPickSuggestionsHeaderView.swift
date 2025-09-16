//
//  AIPickSuggestionsHeaderView.swift
//  BigWarRoom
//
//  AI header section component for AIPickSuggestionsView
//

import SwiftUI

/// AI header section with strategy engine info and draft context
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
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
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
                        HStack(spacing: 4) {
                            Text("Pick")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(myRosterID)")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    if viewModel.isMyTurn {
                        HStack(spacing: 4) {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            Text("YOUR TURN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}