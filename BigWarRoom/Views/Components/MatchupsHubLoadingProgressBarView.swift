//
//  MatchupsHubLoadingProgressBarView.swift
//  BigWarRoom
//
//  Overall progress bar component for MatchupsHubLoadingIndicator
//

import SwiftUI

/// Overall progress bar with gradient fill and shimmer effect
struct MatchupsHubLoadingProgressBarView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)
                    
                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.gpGreen, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0.05, progress), height: 12)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 12)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * progress))
                        .animation(
                            .linear(duration: 2.0).repeatForever(autoreverses: false),
                            value: progress
                        )
                }
            }
            .frame(height: 12)
            
            // Progress text
            HStack {
                Text("Loading your fantasy empire...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.gpGreen)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(maxWidth: 300)
    }
}