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
/// - Horizontal scrolling week grid
/// - Current week highlighting
/// - NFL season awareness (1-18 weeks)
/// - Smooth animations and haptic feedback
/// - Playoff week indicators
struct WeekPickerView: View {
    @Binding var selectedWeek: Int
    @Binding var isPresented: Bool
    @State private var animateIn = false
    
    /// NFL season has 18 weeks (17 regular + playoffs)
    private let maxWeeks = 18
    private let currentNFLWeek = NFLWeekService.shared.currentWeek
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPicker()
                }
            
            VStack(spacing: 0) {
                // Header
                pickerHeader
                
                // Week grid
                weekGrid
                
                // Footer actions
                pickerFooter
            }
            .frame(maxWidth: .infinity)
            .frame(height: 400)
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
        }
        .onAppear {
            animateIn = true
        }
    }
    
    // MARK: - Header
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
    
    // MARK: - Week Grid
    private var weekGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(
                rows: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(1...maxWeeks, id: \.self) { week in
                    weekButton(for: week)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 200)
        .padding(.vertical, 8)
    }
    
    private func weekButton(for week: Int) -> some View {
        let isSelected = week == selectedWeek
        let isCurrent = week == currentNFLWeek
        let isPlayoffs = week > 17
        let isPast = week < currentNFLWeek
        let isFuture = week > currentNFLWeek
        
        return Button(action: {
            selectWeek(week)
        }) {
            VStack(spacing: 6) {
                // Week number
                Text("\(week)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(isSelected ? .black : .white)
                
                // Week label
                Text(weekLabel(for: week))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isSelected ? .black.opacity(0.7) : .gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Status indicator
                statusIndicator(for: week, isSelected: isSelected)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundGradient(for: week, isSelected: isSelected))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor(for: week, isSelected: isSelected), lineWidth: 2)
                    )
                    .shadow(
                        color: shadowColor(for: week, isSelected: isSelected),
                        radius: isSelected ? 8 : 0,
                        x: 0,
                        y: isSelected ? 4 : 0
                    )
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
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
                    selectWeek(currentNFLWeek)
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
                        Text("Week \(selectedWeek)")
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
        } else if week == currentNFLWeek {
            return "CURRENT"
        } else if week < currentNFLWeek {
            return "PAST"
        } else {
            return "FUTURE"
        }
    }
    
    @ViewBuilder
    private func statusIndicator(for week: Int, isSelected: Bool) -> some View {
        let size: CGFloat = 4
        
        if week == currentNFLWeek && !isSelected {
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
        } else if week == currentNFLWeek {
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
        } else if week == currentNFLWeek {
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
    
    private func selectWeek(_ week: Int) {
        // Haptic feedback for selection
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            selectedWeek = week
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
            selectedWeek: .constant(1),
            isPresented: .constant(true)
        )
    }
    .preferredColorScheme(.dark)
}