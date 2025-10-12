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
                    
                    // Colorful linear gradient progress fill!
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.gpGreen, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geometry.size.width * progress), height: 12)
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
            }
        }
        .frame(maxWidth: 300)
        .onChange(of: progress) { oldValue, newValue in
            // print("🔥 PROGRESS BAR: Progress \(oldValue) → \(newValue), width will be \(max(8, 300 * newValue)) pixels")
        }
    }
}