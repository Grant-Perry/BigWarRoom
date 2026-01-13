//
//  WeekPickerView+WeekButton.swift
//  BigWarRoom
//
//  Individual week button component
//

import SwiftUI

struct WeekPickerWeekButton: View {
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
                    .foregroundColor(isSelected ? .black : .white)
                
                // Week start date
                Text(weekPickerViewModel.weekStartDate(for: week))
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(isSelected ? .black.opacity(0.6) : .gray.opacity(0.7))
                    .lineLimit(1)
                
                // Status indicator
                statusIndicator
            }
            .frame(width: 48, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(weekPickerViewModel.backgroundGradient(for: week, isSelected: isSelected))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(weekPickerViewModel.borderColor(for: week, isSelected: isSelected), lineWidth: 1.5)
                    )
                    .shadow(
                        color: weekPickerViewModel.shadowColor(for: week, isSelected: isSelected),
                        radius: isSelected ? 6 : 0,
                        x: 0,
                        y: isSelected ? 3 : 0
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        let size: CGFloat = 3
        
        if week == weekPickerViewModel.weekManager.currentNFLWeek && !isSelected {
            Circle()
                .fill(Color.gpGreen)
                .frame(width: size, height: size)
        } else if week > 17 {
            Circle()
                .fill(Color.purple)
                .frame(width: size, height: size)
        } else {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
        }
    }
}