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
/// Refactored for single responsibility - this view only orchestrates layout and state.
struct WeekPickerView: View {
    @Binding var isPresented: Bool
    
    @Bindable var weekManager: WeekSelectionManager
    @Bindable var yearManager: SeasonYearManager
    
    var onPlayoffsSelected: (() -> Void)?
    
    @State private var animateIn = false
    @State private var showYearPicker = false
    @State private var weekPickerViewModel: WeekPickerViewModel
    
    init(
        weekManager: WeekSelectionManager,
        yearManager: SeasonYearManager,
        isPresented: Binding<Bool>,
        onPlayoffsSelected: (() -> Void)? = nil
    ) {
        self.weekManager = weekManager
        self.yearManager = yearManager
        self._isPresented = isPresented
        self.onPlayoffsSelected = onPlayoffsSelected
        
        // Initialize ViewModel
        self._weekPickerViewModel = State(initialValue: WeekPickerViewModel(
            weekManager: weekManager,
            yearManager: yearManager
        ))
    }

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    if showYearPicker {
                        showYearPicker = false
                    } else {
                        dismissPicker()
                    }
                }
            
            // Main content
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    WeekPickerHeader(
                        weekPickerViewModel: weekPickerViewModel,
                        showYearPicker: $showYearPicker,
                        onDismiss: dismissPicker
                    )
                    
                    WeekPickerGrid(
                        weekPickerViewModel: weekPickerViewModel,
                        onWeekSelect: selectWeek
                    )
                    
                    WeekPickerFooter(
                        weekPickerViewModel: weekPickerViewModel,
                        onCurrentSelect: selectCurrentWeek,
                        onPlayoffsSelect: selectPlayoffs,
                        onConfirm: confirmSelection
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 460)
                .background(pickerBackground)
                .padding(.horizontal, 20)
                .scaleEffect(animateIn ? 1.0 : 0.8)
                .opacity(animateIn ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
                
                Spacer()
            }
            
            // Year Picker Overlay
            if showYearPicker {
                WeekPickerYearPicker(
                    weekPickerViewModel: weekPickerViewModel,
                    showYearPicker: $showYearPicker,
                    onYearSelect: selectYear
                )
            }
        }
        .onAppear {
            animateIn = true
        }
    }
    
    // MARK: - Background
    
    private var pickerBackground: some View {
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
    }
    
    // MARK: - Actions
    
    private func selectYear(_ year: String) {
        weekPickerViewModel.selectYear(year)
        
        // Auto-dismiss after year selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismissPicker()
        }
    }
    
    private func selectWeek(_ week: Int) {
        weekPickerViewModel.selectWeek(week)
        
        // Auto-dismiss after week selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismissPicker()
        }
    }
    
    private func selectCurrentWeek() {
        weekPickerViewModel.selectCurrentWeek()
        
        // Auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismissPicker()
        }
    }
    
    private func selectPlayoffs() {
        weekPickerViewModel.selectPlayoffs()
        
        // Dismiss picker
        dismissPicker()
        
        // Trigger playoff navigation callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onPlayoffsSelected?()
        }
    }
    
    private func confirmSelection() {
        // Haptic feedback
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