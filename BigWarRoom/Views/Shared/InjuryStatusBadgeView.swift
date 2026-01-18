//
//  InjuryStatusBadgeView.swift
//  BigWarRoom
//
//  Small circular injury status badge for player images
//  🔥 REFACTORED: Now uses ColorThemeService for DRY compliance
//

import SwiftUI

struct InjuryStatusBadgeView: View {
    let injuryStatus: String
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(backgroundColor)
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            
            // Status text
            Text(statusText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textColor)
                .minimumScaleFactor(0.8)
        }
    }
    
    // MARK: - Computed Properties (now using ColorThemeService)
    
    private var statusText: String {
        // 🔥 DRY: Delegate to ColorThemeService
        return colorService.injuryStatusText(for: injuryStatus)
    }
    
    private var backgroundColor: Color {
        // 🔥 DRY: Delegate to ColorThemeService
        return colorService.injuryStatusColor(for: injuryStatus)
    }
    
    private var textColor: Color {
        // 🔥 DRY: Delegate to ColorThemeService
        return colorService.injuryStatusTextColor(for: injuryStatus)
    }
}