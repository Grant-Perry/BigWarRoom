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
    
    // MARK: - Dependencies (pass explicitly instead of environment)
    private let weekManager: WeekSelectionManager
    @State private var yearManager = SeasonYearManager.shared
    
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
    
    // MARK: - Initializer
    init(
        showingWeekPicker: Binding<Bool>,
        weekManager: WeekSelectionManager,
        labelText: String = "Week",
        labelFontSize: CGFloat = 14,
        labelFontWeight: Font.Weight = .medium,
        labelColor: Color = .white.opacity(0.8),
        weekNumberFontSize: CGFloat = 24,
        weekNumberFontWeight: Font.Weight = .bold,
        weekNumberColor: Color = .white,
        chevronSize: CGFloat = 12,
        chevronWeight: Font.Weight = .medium,
        chevronColor: Color = .white.opacity(0.8),
        gradientStartColor: Color = .gpGreen,
        gradientEndColor: Color = .blue,
        gradientOpacity: Double = 0.3,
        strokeOpacity: Double = 0.6,
        strokeWidth: CGFloat = 1.5,
        cornerRadius: CGFloat = 20,
        shadowColor: Color = .gpGreen,
        shadowOpacity: Double = 0.2,
        shadowRadius: CGFloat = 8,
        horizontalPadding: CGFloat = 20,
        verticalPadding: CGFloat = 10,
        showYear: Bool = true,
        yearFontSize: CGFloat = 9,
        yearOpacity: Double = 0.65
    ) {
        self._showingWeekPicker = showingWeekPicker
        self.weekManager = weekManager
        self.labelText = labelText
        self.labelFontSize = labelFontSize
        self.labelFontWeight = labelFontWeight
        self.labelColor = labelColor
        self.weekNumberFontSize = weekNumberFontSize
        self.weekNumberFontWeight = weekNumberFontWeight
        self.weekNumberColor = weekNumberColor
        self.chevronSize = chevronSize
        self.chevronWeight = chevronWeight
        self.chevronColor = chevronColor
        self.gradientStartColor = gradientStartColor
        self.gradientEndColor = gradientEndColor
        self.gradientOpacity = gradientOpacity
        self.strokeOpacity = strokeOpacity
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.showYear = showYear
        self.yearFontSize = yearFontSize
        self.yearOpacity = yearOpacity
    }
    
    var body: some View {
        Button(action: {
            showingWeekPicker = true
        }) {
            HStack(spacing: 8) {
                // Week label - show "Playoffs" for weeks 19+
                Text(weekManager.selectedWeek >= 19 ? "Playoffs" : labelText)
                    .font(.system(size: labelFontSize, weight: labelFontWeight))
                    .foregroundColor(labelColor)
                
                // Week number with year underneath, trailing aligned
                // For playoffs, show the playoff round instead of week number
                VStack(alignment: .trailing, spacing: 0) {
                    if weekManager.selectedWeek >= 19 {
                        // Show playoff round name - same size as "Playoffs" label
                        Text(playoffRoundName(for: weekManager.selectedWeek))
                            .font(.system(size: labelFontSize, weight: labelFontWeight, design: .rounded))
                            .foregroundColor(weekNumberColor)
                    } else {
                        Text("\(weekManager.selectedWeek)")
                            .font(.system(size: weekNumberFontSize, weight: weekNumberFontWeight, design: .rounded))
                            .foregroundColor(weekNumberColor)
                    }
                    
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
    
    // MARK: - Helper Methods
    
    /// Get the playoff round name for a given week
    private func playoffRoundName(for week: Int) -> String {
        switch week {
        case 19:
            return "WC" // Wild Card
        case 20:
            return "DIV" // Divisional
        case 21:
            return "CONF" // Conference Championships
        case 22:
            return "PRO" // Pro Bowl
        case 23:
            return "SB" // Super Bowl
        default:
            return "PO" // Generic Playoffs
        }
    }
}

// MARK: - Convenience Initializers

extension TheWeekPicker {
    /// Default Schedule style (green-blue gradient)
    static func scheduleStyle(showingWeekPicker: Binding<Bool>, weekManager: WeekSelectionManager) -> TheWeekPicker {
        TheWeekPicker(showingWeekPicker: showingWeekPicker, weekManager: weekManager)
    }
    
    /// Compact style for tight spaces
    static func compact(showingWeekPicker: Binding<Bool>, weekManager: WeekSelectionManager) -> TheWeekPicker {
        TheWeekPicker(
            showingWeekPicker: showingWeekPicker,
            weekManager: weekManager,
            labelFontSize: 10,
            weekNumberFontSize: 18,
            chevronSize: 10,
            horizontalPadding: 14,
            verticalPadding: 8,
            yearFontSize: 8
        )
    }
    
    /// Blue-only style
    static func blueStyle(showingWeekPicker: Binding<Bool>, weekManager: WeekSelectionManager) -> TheWeekPicker {
        TheWeekPicker(
            showingWeekPicker: showingWeekPicker,
            weekManager: weekManager,
            gradientStartColor: .blue,
            gradientEndColor: .blue,
            shadowColor: .blue
        )
    }
}

#Preview("The Week Picker") {
    let nflWeekService = NFLWeekService(apiClient: SleeperAPIClient())
    let weekManager = WeekSelectionManager(nflWeekService: nflWeekService)
    
    return ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Default
            TheWeekPicker(showingWeekPicker: .constant(false), weekManager: weekManager)
            
            // Compact
            TheWeekPicker.compact(showingWeekPicker: .constant(false), weekManager: weekManager)
            
            // Blue style
            TheWeekPicker.blueStyle(showingWeekPicker: .constant(false), weekManager: weekManager)
            
            // Custom
            TheWeekPicker(
                showingWeekPicker: .constant(false),
                weekManager: weekManager,
                weekNumberFontSize: 32,
                gradientStartColor: .orange,
                gradientEndColor: .red,
                shadowColor: .orange
            )
        }
    }
}