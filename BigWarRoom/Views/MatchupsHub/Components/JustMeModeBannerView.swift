//
//  JustMeModeBannerView.swift
//  BigWarRoom
//
//  Just Me Mode banner component
//

import SwiftUI

/// Banner component displayed when Just Me Mode is active
struct JustMeModeBannerView: View {
    var body: some View {
        VStack(spacing: 8) {
            BannerTitleRow()
            BannerSubtitle()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(bannerBackground)
        .padding(.horizontal, 20)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    // MARK: - Background Styling
    
    private var bannerBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        Color.nyyDark.opacity(0.8),
                        Color.nyyDark.opacity(0.6), 
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.4), .blue.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Supporting Components

/// Banner title row with emojis and gradient text
private struct BannerTitleRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("🙍")
                .font(.system(size: 16))
            
            Text("JUST ME MODE")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gpGreen, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("💎")
                .font(.system(size: 16))
        }
    }
}

/// Banner subtitle explaining the mode
private struct BannerSubtitle: View {
    var body: some View {
        Text("Focus view - your performance only")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.gray)
    }
}