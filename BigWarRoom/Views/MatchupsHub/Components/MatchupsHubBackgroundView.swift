//
//  MatchupsHubBackgroundView.swift
//  BigWarRoom
//
//  Background gradient component for MatchupsHub
//

import SwiftUI

/// Background gradient for MatchupsHub
struct MatchupsHubBackgroundView: View {
    var body: some View {
        ZStack {
            // BG4 asset background
            Image("BG4")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.5) // Changed from 0.65 to 0.5
                .ignoresSafeArea(.all)
            
            // Subtle overlay gradient for depth
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}