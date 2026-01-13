//
//  WeekPickerView+YearPicker.swift
//  BigWarRoom
//
//  Year picker overlay component
//

import SwiftUI

struct WeekPickerYearPicker: View {
    let weekPickerViewModel: WeekPickerViewModel
    @Binding var showYearPicker: Bool
    let onYearSelect: (String) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Select Season")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showYearPicker = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                Divider()
                    .background(Color.gpGreen.opacity(0.3))
                
                // Year list
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(weekPickerViewModel.yearRange, id: \.self) { year in
                            yearRowButton(for: year)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 300)
            }
            .background(yearPickerBackground)
            .padding(.horizontal, 40)
            .padding(.bottom, 80)
            .transition(.scale.combined(with: .opacity))
            
            Spacer()
        }
    }
    
    private func yearRowButton(for year: String) -> some View {
        let isSelected = year == weekPickerViewModel.yearManager.selectedYear
        
        return Button(action: {
            onYearSelect(year)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showYearPicker = false
            }
        }) {
            HStack {
                Text(year)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ?
                          AnyShapeStyle(LinearGradient(colors: [.gpGreen, .blue], startPoint: .leading, endPoint: .trailing)) :
                          AnyShapeStyle(Color.gray.opacity(0.1)))
            )
        }
    }
    
    private var yearPickerBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.6), .blue.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
    }
}