//
//  WeekPickerView+Footer.swift
//  BigWarRoom
//
//  Footer component with Current, Playoffs, and Confirm buttons
//

import SwiftUI

struct WeekPickerFooter: View {
    let weekPickerViewModel: WeekPickerViewModel
    let onCurrentSelect: () -> Void
    let onPlayoffsSelect: () -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Divider()
                .background(Color.gpGreen.opacity(0.3))
            
            HStack(spacing: 10) {
                // Current Week Quick Select
                Button(action: onCurrentSelect) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gpGreen)
                        Text("Current")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gpGreen)
                            .fixedSize()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gpGreen.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gpGreen.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                
                // Playoffs Button
                Button(action: onPlayoffsSelect) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                        Text("Playoffs")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.purple)
                            .fixedSize()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.purple.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                // Confirm Selection
                Button(action: onConfirm) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("Week \(weekPickerViewModel.weekManager.selectedWeek)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.gpGreen, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}