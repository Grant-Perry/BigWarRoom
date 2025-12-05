//
//  WeekPickerView.swift
//  BigWarRoom
//
//  🗓️ WEEK PICKER COMPONENT 🗓️
//  Time travel through the fantasy season
//

import SwiftUI

/// **WeekPickerView**
/// 
/// A sleek week selector that appears when the user taps the "WEEK X" stat card.
/// Features:
/// - Left-to-right week arrangement (1,2,3,4,5...)
/// - All 18 weeks fit with proper scrolling
/// - Week dates under PAST/CURRENT/FUTURE labels
/// - Current week highlighting
/// - NFL season awareness (1-18 weeks)
/// - Smooth animations and haptic feedback
/// - Playoff week indicators
/// - **USES WeekSelectionManager AS SSOT**
struct WeekPickerView: View {
    @Binding var isPresented: Bool
    
    // 🔥 PHASE 2.5: Accept dependencies instead of using .shared
    private let weekManager: WeekSelectionManager
    private let yearManager: SeasonYearManager
    
    @State private var animateIn = false
    
    /// NFL season has 18 weeks (17 regular + playoffs)
    private let maxWeeks = 18
    
    /// NFL season start date - calculated from SeasonYearManager (SOT)
    private var seasonStartDate: Date {
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
    
    // 🔥 PHASE 2.5: Dependency injection initializer
    init(
        weekManager: WeekSelectionManager,
        isPresented: Binding<Bool>
    ) {
        self.weekManager = weekManager
        self.yearManager = SeasonYearManager.shared // TODO: Convert this too
        self._isPresented = isPresented
    }

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPicker()
                }
            
            // 🔥 FIX: Add proper vertical centering for sheet presentation
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Header with year picker
                    pickerHeader
                    
                    // Week grid
                    weekGrid
                    
                    // Footer actions
                    pickerFooter
                }
                .frame(maxWidth: .infinity)
                .frame(height: 450) // Increased height for year picker
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.95),
                                    Color.gray.opacity(0.1),
                                    Color.black.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [.gpGreen.opacity(0.6), .blue.opacity(0.6), .gpGreen.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .gpGreen.opacity(0.3), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 20)
                .scaleEffect(animateIn ? 1.0 : 0.8)
                .opacity(animateIn ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
                
                Spacer()
            }
        }
        .onAppear {
            animateIn = true
        }
    }
    
    // MARK: - Header with Year Picker
    private var pickerHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🗓️")
                    .font(.system(size: 24))
                
                Text("SELECT WEEK")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .gpGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                Button(action: dismissPicker) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            
            // Year Picker Row
            HStack(spacing: 8) {
                Text("Season:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                ForEach(yearManager.availableYears, id: \.self) { year in
                    yearPickerButton(for: year)
                }
                
                Spacer()
            }
            
            Text("Choose a week to view matchups")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Divider()
                .background(Color.gpGreen.opacity(0.3))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private func yearPickerButton(for year: String) -> some View {
        let isSelected = year == yearManager.selectedYear
        
        return Button(action: {
            selectYear(year)
        }) {
            Text(year)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? 
                              LinearGradient(colors: [.gpGreen, .blue], startPoint: .leading, endPoint: .trailing) :
                              LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.white.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
    }
    
    // MARK: - Week Grid (Fixed: Left-to-Right Layout + All Weeks Fit)
    private var weekGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 12
            ) {
                ForEach(1...maxWeeks, id: \.self) { week in
                    weekButton(for: week)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }
    
    private func weekButton(for week: Int) -> some View {
        let isSelected = week == weekManager.selectedWeek
        let isCurrent = week == weekManager.currentNFLWeek
        let isPlayoffs = week > 17
        let isPast = week < weekManager.currentNFLWeek
        let isFuture = week > weekManager.currentNFLWeek
        
        return Button(action: {
            selectWeek(week)
        }) {
            VStack(spacing: 4) {
                // Week number
                Text("\(week)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(isSelected ? .black : .white)
                
                // Week label with date
                VStack(spacing: 1) {
                    Text(weekLabel(for: week))
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(isSelected ? .black.opacity(0.7) : .gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    // Week start date
                    Text(weekStartDate(for: week))
                        .font(.system(size: 6, weight: .medium))
                        .foregroundColor(isSelected ? .black.opacity(0.5) : .gray.opacity(0.8))
                        .lineLimit(1)
                }
                
                // Status indicator
                statusIndicator(for: week, isSelected: isSelected)
            }
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundGradient(for: week, isSelected: isSelected))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor(for: week, isSelected: isSelected), lineWidth: 1.5)
                    )
                    .shadow(
                        color: shadowColor(for: week, isSelected: isSelected),
                        radius: isSelected ? 6 : 0,
                        x: 0,
                        y: isSelected ? 3 : 0
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
    }
    
    // MARK: - Footer
    private var pickerFooter: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.gpGreen.opacity(0.3))
            
            HStack(spacing: 20) {
                // Current Week Quick Select
                Button(action: {
                    selectCurrentWeek()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.circle.fill")
                            .foregroundColor(.gpGreen)
                        Text("Current Week")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gpGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gpGreen.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gpGreen.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                // Confirm Selection
                Button(action: {
                    confirmSelection()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("Week \(weekManager.selectedWeek)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
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
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Functions
    
    private func weekLabel(for week: Int) -> String {
        if week > 17 {
            return "PLAYOFFS"
        } else if week == weekManager.currentNFLWeek {
            return "CURRENT"
        } else if week < weekManager.currentNFLWeek {
            return "PAST"
        } else {
            return "FUTURE"
        }
    }
    
    /// Calculate the start date for a given NFL week
    private func weekStartDate(for week: Int) -> String {
        let calendar = Calendar.current
        let weekStartDate = calendar.date(byAdding: .day, value: (week - 1) * 7, to: seasonStartDate)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStartDate)
    }
    
    @ViewBuilder
    private func statusIndicator(for week: Int, isSelected: Bool) -> some View {
        let size: CGFloat = 3
        
        if week == weekManager.currentNFLWeek && !isSelected {
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
    
    private func backgroundGradient(for week: Int, isSelected: Bool) -> some ShapeStyle {
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
        } else if week > 17 {
            return LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.15)],
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
    
    private func borderColor(for week: Int, isSelected: Bool) -> Color {
        if isSelected {
            return .white.opacity(0.8)
        } else if week == weekManager.currentNFLWeek {
            return .gpGreen.opacity(0.6)
        } else if week > 17 {
            return .purple.opacity(0.4)
        } else {
            return .gray.opacity(0.2)
        }
    }
    
    private func shadowColor(for week: Int, isSelected: Bool) -> Color {
        if isSelected {
            return .gpGreen.opacity(0.6)
        }
        return .clear
    }
    
    // MARK: - Actions
    
    private func selectYear(_ year: String) {
        // Haptic feedback for year selection
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            yearManager.selectYear(year)
        }
    }
    
    private func selectWeek(_ week: Int) {
        // Haptic feedback for selection
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            weekManager.selectWeek(week)
        }
        
        // Auto-dismiss after week selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismissPicker()
        }
    }
    
    private func selectCurrentWeek() {
        // Haptic feedback for current week selection
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        weekManager.resetToCurrentWeek()
        
        // Auto-dismiss after current week selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismissPicker()
        }
    }
    
    private func confirmSelection() {
        // Haptic feedback for confirmation
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        dismissPicker()
    }
    
    private func dismissPicker() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            animateIn = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        WeekPickerView(
            weekManager: WeekSelectionManager(nflWeekService: NFLWeekService(apiClient: SleeperAPIClient())),
            isPresented: .constant(true)
        )
    }
    .preferredColorScheme(.dark)
}