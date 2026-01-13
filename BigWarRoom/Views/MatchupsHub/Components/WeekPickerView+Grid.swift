//
//  WeekPickerView+Grid.swift
//  BigWarRoom
//
//  Week grid component with regular and playoff weeks
//

import SwiftUI

struct WeekPickerGrid: View {
    let weekPickerViewModel: WeekPickerViewModel
    let onWeekSelect: (Int) -> Void
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Regular season weeks (1-18)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ],
                    spacing: 6
                ) {
                    ForEach(1...18, id: \.self) { week in
                        WeekPickerWeekButton(
                            week: week,
                            weekPickerViewModel: weekPickerViewModel,
                            onSelect: onWeekSelect
                        )
                    }
                }
                
                // Playoff weeks section
                VStack(spacing: 6) {
                    // Section header
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        
                        Text("PLAYOFF WEEKS")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.purple)
                            .kerning(0.8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    // Playoff weeks grid (19-23)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ],
                        spacing: 6
                    ) {
                        ForEach(19...23, id: \.self) { week in
                            WeekPickerPlayoffButton(
                                week: week,
                                weekPickerViewModel: weekPickerViewModel,
                                onSelect: onWeekSelect
                            )
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 260)
        .padding(.vertical, 6)
    }
}