//
//  AllLivePlayersLoadingView.swift
//  BigWarRoom
//
//  Loading state view for All Live Players
//

import SwiftUI

/// Loading state with spinning football animation
struct AllLivePlayersLoadingView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Clean spinning football
            FantasyLoadingIndicator()
                .scaleEffect(1.2)
            
            VStack(spacing: 12) {
                Text("Loading Players")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Fetching live player data from your leagues...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    AllLivePlayersLoadingView()
}