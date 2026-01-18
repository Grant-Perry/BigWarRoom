//
//  ChoppedRosterLoadingView.swift
//  BigWarRoom
//
//  🏈 CHOPPED ROSTER LOADING VIEW 🏈
//  Loading state display for roster data
//

import SwiftUI

/// **ChoppedRosterLoadingView**
/// 
/// Displays loading state while roster data is being fetched
struct ChoppedRosterLoadingView: View {
    let ownerName: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading \(ownerName)'s Roster...")
                .font(.title3)
                .foregroundColor(.white)
        }
    }
}