//
//  StatBubbleView.swift
//  BigWarRoom
//
//  Reusable stat bubble component - DRY with StatBlock but more stylized
//

import SwiftUI

/// Enhanced stat bubble for detailed stats display
/// DRY with StatBlock but with more styling options for complex stats views
struct StatBubbleView: View {
    let value: String
    let label: String
    let color: Color
    let isLarge: Bool
    
    init(value: String, label: String, color: Color, isLarge: Bool = false) {
        self.value = value
        self.label = label
        self.color = color
        self.isLarge = isLarge
    }
    
    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(isLarge ? .callout : .caption)
                .fontWeight(.black)
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, isLarge ? 12 : 8)
        .padding(.vertical, isLarge ? 8 : 6)
        .background(
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: isLarge ? 10 : 6)
                    .fill(color.opacity(0.8))
                    .blur(radius: 1)
                
                // Main background
                RoundedRectangle(cornerRadius: isLarge ? 8 : 5)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: isLarge ? 8 : 5)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
        .scaleEffect(isLarge ? 1.03 : 1.0)
    }
}