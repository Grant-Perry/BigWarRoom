//
//  WeekPickerViewModel.swift
//  BigWarRoom
//
//  ViewModel for WeekPicker UI logic
//

import SwiftUI

@Observable
class WeekPickerViewModel {
    // Dependencies
    let weekManager: WeekSelectionManager
    let yearManager: SeasonYearManager
    
    // Constants
    let maxWeeks = 23  // 18 regular + 5 playoff weeks
    
    // Computed properties
    var yearRange: [String] {
        let currentNFLYear = NFLWeekCalculator.getCurrentSeasonYear()
        let maxYear = currentNFLYear + 1
        return (2012...maxYear).map { String($0) }.reversed()
    }
    
    var seasonStartDate: Date {
        let calendar = Calendar.current
        let selectedYear = Int(yearManager.selectedYear) ?? 2025
        
        // Known season start dates
        if selectedYear == 2025 {
            return calendar.date(from: DateComponents(year: 2025, month: 9, day: 4))!
        } else if selectedYear == 2024 {
            return calendar.date(from: DateComponents(year: 2024, month: 9, day: 5))!
        } else {
            // Fallback: find first Thursday of September
            var startDate = calendar.date(from: DateComponents(year: selectedYear, month: 9, day: 1))!
            while calendar.component(.weekday, from: startDate) != 5 { // Thursday = 5
                startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            }
            return startDate
        }
    }
    
    init(weekManager: WeekSelectionManager, yearManager: SeasonYearManager) {
        self.weekManager = weekManager
        self.yearManager = yearManager
    }
    
    // MARK: - Week Formatting
    
    func weekLabel(for week: Int) -> String {
        if week > 18 {
            switch week {
            case 19: return "WILD CARD"
            case 20: return "DIVISIONAL"
            case 21: return "CONF CHAMP"
            case 22: return "PRO BOWL"
            case 23: return "SUPER BOWL"
            default: return "PLAYOFFS"
            }
        } else if week == weekManager.currentNFLWeek {
            return "CURRENT"
        } else {
            return ""
        }
    }
    
    func weekStartDate(for week: Int) -> String {
        let calendar = Calendar.current
        let weekStartDate = calendar.date(byAdding: .day, value: (week - 1) * 7, to: seasonStartDate)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStartDate)
    }
    
    func playoffRoundAbbr(for week: Int) -> String {
        switch week {
        case 19: return "WC"
        case 20: return "DIV"
        case 21: return "CONF"
        case 22: return "PRO"
        case 23: return "SB"
        default: return "PO"
        }
    }
    
    // MARK: - UI Styling
    
    func backgroundGradient(for week: Int, isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return LinearGradient(
                colors: [.gpGreen, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if week == weekManager.currentNFLWeek {
            return LinearGradient(
                colors: [Color.gpGreen.opacity(0.2), Color.blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    func borderColor(for week: Int, isSelected: Bool) -> Color {
        if isSelected {
            return .white.opacity(0.8)
        } else if week == weekManager.currentNFLWeek {
            return .gpGreen.opacity(0.6)
        } else {
            return .gray.opacity(0.2)
        }
    }
    
    func shadowColor(for week: Int, isSelected: Bool) -> Color {
        if isSelected {
            return .gpGreen.opacity(0.6)
        }
        return .clear
    }
    
    func playoffButtonBackground(isSelected: Bool, isCurrent: Bool) -> some ShapeStyle {
        if isSelected {
            return LinearGradient(
                colors: [.purple, .purple.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isCurrent {
            return LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    func playoffButtonBorder(isSelected: Bool, isCurrent: Bool) -> Color {
        if isSelected {
            return .white.opacity(0.8)
        } else if isCurrent {
            return .purple.opacity(0.8)
        } else {
            return .purple.opacity(0.4)
        }
    }
    
    // MARK: - Actions
    
    func selectYear(_ year: String) {
        DebugPrint(mode: .weekCheck, "🔥 WeekPickerViewModel: selectYear called with year: \(year)")
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        yearManager.selectYear(year)
        
        // Trigger immediate data refresh
        weekManager.selectWeek(weekManager.selectedWeek)
    }
    
    func selectWeek(_ week: Int) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        weekManager.selectWeek(week)
    }
    
    func selectCurrentWeek() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        weekManager.resetToCurrentWeek()
    }
    
    func selectPlayoffs() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        weekManager.selectWeek(19)
    }
}