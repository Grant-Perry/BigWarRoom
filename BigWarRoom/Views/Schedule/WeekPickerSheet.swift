//
//  WeekPickerSheet.swift
//  BigWarRoom
//
//  Week selection sheet for NFL Schedule
//

import SwiftUI

struct WeekPickerSheet: View {
    @Binding var selectedWeek: Int
    let onWeekSelected: (Int) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Select Week")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.9))
                
                // Week grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(1...18, id: \.self) { week in
                            Button(action: { onWeekSelected(week) }) {
                                VStack(spacing: 6) {
                                    Text("WEEK")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(selectedWeek == week ? .black : .white.opacity(0.7))
                                    
                                    Text("\(week)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(selectedWeek == week ? .black : .white)
                                }
                                .frame(height: 60)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedWeek == week ? Color.white : Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(Color.black)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Week Picker") {
    WeekPickerSheet(selectedWeek: .constant(1)) { week in
        print("Selected week \(week)")
    }
}