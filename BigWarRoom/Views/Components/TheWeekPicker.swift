//
//  TheWeekPicker.swift
//  BigWarRoom
//
//  🗓️ Reusable week picker component with customizable styling
//

import SwiftUI

struct TheWeekPicker: View {
    // MARK: - Required
    @Binding var showingWeekPicker: Bool
    
    // MARK: - Optional Customization (with defaults matching Schedule style)
    
    // Text customization
    var labelText: String = "Week"
    var labelFontSize: CGFloat = 14
    var labelFontWeight: Font.Weight = .medium
    var labelColor: Color = .white.opacity(0.8)
    
    var weekNumberFontSize: CGFloat = 24
    var weekNumberFontWeight: Font.Weight = .bold
    var weekNumberColor: Color = .white
    
    var chevronSize: CGFloat = 12
    var chevronWeight: Font.Weight = .medium
    var chevronColor: Color = .white.opacity(0.8)
    
    // Background customization
    var gradientStartColor: Color = .gpGreen
    var gradientEndColor: Color = .blue
    var gradientOpacity: Double = 0.3
    var strokeOpacity: Double = 0.6
    var strokeWidth: CGFloat = 1.5
    var cornerRadius: CGFloat = 20
    var shadowColor: Color = .gpGreen
    var shadowOpacity: Double = 0.2
    var shadowRadius: CGFloat = 8
    
    // Padding
    var horizontalPadding: CGFloat = 20
    var verticalPadding: CGFloat = 10
    
    // Year display
    var showYear: Bool = true
    var yearFontSize: CGFloat = 9
    var yearOpacity: Double = 0.65
    
    // State references
    @State private var weekManager = WeekSelectionManager.shared
    @State private var yearManager = SeasonYearManager.shared
    
    var body: some View {
        Button(action: {
            showingWeekPicker = true
        }) {
            HStack(spacing: 8) {
                // Week label
                Text(labelText)
                    .font(.system(size: labelFontSize, weight: labelFontWeight))
                    .foregroundColor(labelColor)
                
                // Week number with year underneath, trailing aligned
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(weekManager.selectedWeek)")
                        .font(.system(size: weekNumberFontSize, weight: weekNumberFontWeight, design: .rounded))
                        .foregroundColor(weekNumberColor)
                    
                    if showYear {
                        Text("\(yearManager.selectedYear)")
                            .font(.system(size: yearFontSize, weight: .medium))
                            .italic()
                            .foregroundColor(.secondary)
                            .opacity(yearOpacity)
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: chevronSize, weight: chevronWeight))
                    .foregroundColor(chevronColor)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                gradientStartColor.opacity(gradientOpacity),
                                gradientEndColor.opacity(gradientOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        gradientStartColor.opacity(strokeOpacity),
                                        gradientEndColor.opacity(strokeOpacity)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: strokeWidth
                            )
                    )
                    .shadow(color: shadowColor.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Convenience Initializers

extension TheWeekPicker {
    /// Default Schedule style (green-blue gradient)
    static func scheduleStyle(showingWeekPicker: Binding<Bool>) -> TheWeekPicker {
        TheWeekPicker(showingWeekPicker: showingWeekPicker)
    }
    
    /// Compact style for tight spaces
    static func compact(showingWeekPicker: Binding<Bool>) -> TheWeekPicker {
        TheWeekPicker(
            showingWeekPicker: showingWeekPicker,
            labelFontSize: 10,
            weekNumberFontSize: 18,
            chevronSize: 10,
            horizontalPadding: 14,
            verticalPadding: 8,
            yearFontSize: 8
        )
    }
    
    /// Blue-only style
    static func blueStyle(showingWeekPicker: Binding<Bool>) -> TheWeekPicker {
        TheWeekPicker(
            showingWeekPicker: showingWeekPicker,
            gradientStartColor: .blue,
            gradientEndColor: .blue,
            shadowColor: .blue
        )
    }
}

#Preview("The Week Picker") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Default
            TheWeekPicker(showingWeekPicker: .constant(false))
            
            // Compact
            TheWeekPicker.compact(showingWeekPicker: .constant(false))
            
            // Blue style
            TheWeekPicker.blueStyle(showingWeekPicker: .constant(false))
            
            // Custom
            TheWeekPicker(
                showingWeekPicker: .constant(false),
                weekNumberFontSize: 32,
                gradientStartColor: .orange,
                gradientEndColor: .red,
                shadowColor: .orange
            )
        }
    }
}

