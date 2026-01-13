//
//  WeekPickerView+Header.swift
//  BigWarRoom
//
//  Header component with title, year picker, and close button
//

import SwiftUI

struct WeekPickerHeader: View {
    let weekPickerViewModel: WeekPickerViewModel
    @Binding var showYearPicker: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("🗓️")
                    .font(.system(size: 20))
                
                Text("Select Week or Season Year")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .gpGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            
            // Year Picker Button
            HStack(spacing: 8) {
                Text("Season:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showYearPicker.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(weekPickerViewModel.yearManager.selectedYear)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Image(systemName: showYearPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.gpGreen, .blue], startPoint: .leading, endPoint: .trailing))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
            }
            
            Text("Choose a week to view matchups")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            Divider()
                .background(Color.gpGreen.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}