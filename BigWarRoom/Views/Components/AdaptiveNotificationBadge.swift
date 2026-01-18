//
//  AdaptiveNotificationBadge.swift
//  BigWarRoom
//
//  Adaptive notification badge - DEPRECATED - Use View.notificationBadge() extension instead
//

import SwiftUI

/// DEPRECATED: Use View.notificationBadge() extension instead
/// This component is kept for backward compatibility but new code should use the extension method
struct AdaptiveNotificationBadge: View {
    let count: Int
    let fontSize: CGFloat = 10
    let badgeColor: Color = .red
    
    private var countText: String {
        "\(count)"
    }
    
    private var isThreeDigits: Bool {
        count >= 100
    }
    
    private var badgeWidth: CGFloat {
        isThreeDigits ? 26 : 18 // Oval width for 3+ digits
    }
    
    private var badgeHeight: CGFloat {
        18 // Keep height consistent
    }
    
    var body: some View {
        ZStack {
            // Adaptive shape - circle for <100, oval for ≥100
            if isThreeDigits {
                Capsule()
                    .fill(badgeColor)
                    .frame(width: badgeWidth, height: badgeHeight)
            } else {
                Circle()
                    .fill(badgeColor)
                    .frame(width: badgeWidth, height: badgeHeight)
            }
            
            // Text with negative kerning for tighter digits
            Text(countText)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.white)
                .kerning(-1.5) // Tighter kerning as requested
        }
    }
}