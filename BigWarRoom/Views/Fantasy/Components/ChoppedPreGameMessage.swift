//
//  ChoppedPreGameMessage.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Pre-game message when games haven't started
struct ChoppedPreGameMessage: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("📊 GAMES HAVEN'T STARTED")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.orange)
                .tracking(1)
            
            Text("Tap any manager below to view their lineup")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}