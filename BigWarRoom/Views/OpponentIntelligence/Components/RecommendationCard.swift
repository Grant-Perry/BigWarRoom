//
//  RecommendationCard.swift
//  BigWarRoom
//
//  Strategic recommendation card for opponent intelligence
//

import SwiftUI

/// Card displaying strategic recommendations based on opponent analysis
struct RecommendationCard: View {
    let recommendation: StrategicRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            VStack(spacing: 4) {
                Text(recommendation.type.emoji)
                    .font(.system(size: 20))
                
                Circle()
                    .fill(recommendation.priority.color)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 40)
            
            // Recommendation content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(recommendation.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Description
                Text(recommendation.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Actionable indicator
            if recommendation.actionable {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    
                    Text("ACTION")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(recommendation.priority.color.opacity(0.5), lineWidth: 1)
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            recommendation.priority.color.opacity(0.1),
                            recommendation.priority.color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}