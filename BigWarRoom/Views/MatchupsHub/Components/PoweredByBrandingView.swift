//
//  PoweredByBrandingView.swift
//  BigWarRoom
//
//  Powered by branding section component
//

import SwiftUI

/// Branding component for BigWarRoom powered by section
struct PoweredByBrandingView: View {
    var body: some View {
        VStack(spacing: 8) {
            BrandingTitleRow()
            BrandingSubtitle()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(brandingBackground)
    }
    
    // MARK: - Background Styling
    
    private var brandingBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Supporting Components

/// Branding title row with icons and gradient text
private struct BrandingTitleRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gpGreen)
            
            Text("POWERED BY BIG WARROOM")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gpGreen, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Image(systemName: "paperplane.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.gpGreen)
        }
    }
}

/// Branding subtitle
private struct BrandingSubtitle: View {
    var body: some View {
        Text("The ultimate fantasy football command center")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.gray)
    }
}