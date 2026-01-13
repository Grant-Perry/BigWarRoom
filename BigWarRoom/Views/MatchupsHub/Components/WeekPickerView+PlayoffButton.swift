//
//  WeekPickerView+PlayoffButton.swift
//  BigWarRoom
//
//  Individual playoff week button component
//

import SwiftUI

struct WeekPickerPlayoffButton: View {
    let week: Int
    let weekPickerViewModel: WeekPickerViewModel
    let onSelect: (Int) -> Void
    
    private var isSelected: Bool {
        week == weekPickerViewModel.weekManager.selectedWeek
    }
    
    private var isCurrent: Bool {
        week == weekPickerViewModel.weekManager.currentNFLWeek
    }
    
    var body: some View {
        Button(action: {
            onSelect(week)
        }) {
            VStack(spacing: 1) {
                // Week number
                Text("\(week)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .white : .purple)
                
                // Playoff round abbreviation
                Text(weekPickerViewModel.playoffRoundAbbr(for: week))
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .purple.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                // Week start date
                Text(weekPickerViewModel.weekStartDate(for: week))
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.6) : .purple.opacity(0.5))
                    .lineLimit(1)
                
                // Status indicator
                if isCurrent {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 3, height: 3)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 3, height: 3)
                }
            }
            .frame(width: 48, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(weekPickerViewModel.playoffButtonBackground(isSelected: isSelected, isCurrent: isCurrent))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(weekPickerViewModel.playoffButtonBorder(isSelected: isSelected, isCurrent: isCurrent), lineWidth: 1.5)
                    )
                    .shadow(
                        color: isSelected ? Color.purple.opacity(0.6) : .clear,
                        radius: isSelected ? 6 : 0,
                        x: 0,
                        y: isSelected ? 3 : 0
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
    }
}