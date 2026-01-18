//
//  ChoppedRosterErrorView.swift
//  BigWarRoom
//
//  🏈 CHOPPED ROSTER ERROR VIEW 🏈
//  Error state display for roster loading failures
//

import SwiftUI

/// **ChoppedRosterErrorView**
/// 
/// Displays error state when roster loading fails
struct ChoppedRosterErrorView: View {
    let errorMessage: String?
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Failed to Load Roster")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let error = errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}