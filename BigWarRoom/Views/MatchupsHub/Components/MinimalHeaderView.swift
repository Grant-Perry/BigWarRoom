//
//  MinimalHeaderView.swift
//  BigWarRoom
//
//  Clean minimal header for Mission Control redesign
//

import SwiftUI

/// Minimal header component - just essential navigation and actions
struct MinimalHeaderView: View {
    let selectedWeek: Int
    let onWeekPickerTapped: () -> Void
    let onSettingsTapped: () -> Void
    
    var body: some View {
        HStack {
            // Week selector - primary action
            Button(action: onWeekPickerTapped) {
                HStack(spacing: 6) {
                    Text("Week \(selectedWeek)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Settings gear - secondary action
            Button(action: onSettingsTapped) {
                Image(systemName: "gear")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}