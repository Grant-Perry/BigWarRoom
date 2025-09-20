//
//  ChoppedApocalypticBackground.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Apocalyptic background with animated danger effects
struct ChoppedApocalypticBackground: View {
    let shouldShowDangerBackground: Bool
    let dangerPulse: Bool
    
    var body: some View {
        ZStack {
            // BG9 background - simple and clean
            Image("BG9")
                .resizable()
                .scaledToFill()
                .opacity(0.65)
                .ignoresSafeArea(.all)
            
            // Dark overlay for readability
            Color.black
                .opacity(0.5)
                .ignoresSafeArea(.all)
            
            // Animated danger gradient for critical situations
            if shouldShowDangerBackground {
                LinearGradient(
                    gradient: Gradient(colors: [
                        .red.opacity(0.1),
                        .black.opacity(0.3),
                        .red.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)
                .opacity(dangerPulse ? 0.3 : 0.1)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: dangerPulse)
            }
        }
        .allowsHitTesting(false) // Allow touches to pass through to the ScrollView
    }
}