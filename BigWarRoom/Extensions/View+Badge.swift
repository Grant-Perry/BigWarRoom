//
//  View+Badge.swift
//  BigWarRoom
//
//  View extension for iOS notification badges - DRY and reusable across the platform
//

import SwiftUI

extension View {
    /// Apply iOS notification badge matching Apple's official specifications
    /// - Parameters:
    ///   - count: The number to display in the badge
    ///   - xOffset: Horizontal offset from the view's trailing edge (default: 4)
    ///   - yOffset: Vertical offset from the view's top edge (default: -8)
    ///   - badgeColor: Badge background color (default: Apple's system red #FF3B30)
    /// - Returns: View with badge overlay
   func notificationBadge(count: Int, xOffset: CGFloat = 4, yOffset: CGFloat = -8, badgeColor: Color = .gpRedPink) -> some View {
        ZStack(alignment: .topTrailing) {
            self
            
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .default))
					.kerning(-0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, count >= 10 ? 6 : 4) // More padding for 2+ digits
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(badgeColor) // Apple's system red #FF3B30
                    )
                    .frame(minWidth: 20, minHeight: 20) // Minimum 20px as per Apple specs
                    .offset(x: xOffset, y: yOffset)
            }
        }
    }
}

#Preview("Badge Extension Examples") {
    VStack(spacing: 40) {
        HStack(spacing: 40) {
            // Examples with different counts - matching iOS specs
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 3)
            
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 16)
            
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 142)
            
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 400)
        }
        
        HStack(spacing: 40) {
            // Test with text elements
            Text("Mission Control")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .notificationBadge(count: 16, xOffset: 4, yOffset: -8)
            
            Text("All Rostered Players")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
				.notificationBadge(count: 146, xOffset: 24, yOffset: -8)
        }
    }
    .padding()
    .background(Color.black)
}
