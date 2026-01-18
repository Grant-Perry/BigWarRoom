//
//  FantasyPlayerCardWatchButton.swift
//  BigWarRoom
//
//  Watch toggle button for fantasy player cards
//

import SwiftUI

/// Watch toggle button for player cards
struct FantasyPlayerCardWatchButton: View {
    let isWatched: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: onToggle) {
                    Image(systemName: isWatched ? "eye.fill" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isWatched ? .gpYellow : .white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
            Spacer()
        }
    }
}