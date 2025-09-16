//
//  NonMicroEliminatedBackground.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Background for eliminated cards
struct NonMicroEliminatedBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                // ELIMINATED GRADIENT: Use gpRedPink
                LinearGradient(
                    colors: [
                        Color.gpRedPink.opacity(0.8),
                        Color.black.opacity(0.9),
                        Color.gpRedPink.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4)) // Darken for readability
            )
    }
}