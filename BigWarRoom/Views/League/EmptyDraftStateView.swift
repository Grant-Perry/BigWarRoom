//
//  EmptyDraftStateView.swift
//  BigWarRoom
//
//  Component for displaying empty draft state with call-to-action
//

import SwiftUI

/// Component for displaying empty draft board state
struct EmptyDraftStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Draft Connected")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Connect to a live draft to see the draft board")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Go to War Room") {
                // This will be handled by parent TabView
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
}