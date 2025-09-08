//
//  MatchupsHubView+Actions.swift
//  BigWarRoom
//
//  Action handlers and business logic for MatchupsHubView
//

import SwiftUI

// MARK: - Actions & Business Logic
extension MatchupsHubView {
    
    // MARK: - Data Loading Actions
    func loadInitialData() {
        Task {
            if selectedWeek != NFLWeekService.shared.currentWeek {
                await viewModel.loadMatchupsForWeek(selectedWeek)
            } else {
                await viewModel.loadAllMatchups()
            }
        }
    }
    
    func handlePullToRefresh() async {
        refreshing = true
        await viewModel.manualRefresh()
        refreshing = false
        
        // Reset countdown timer
        refreshCountdown = Double(AppConstants.MatchupRefresh)
        
        // Force UI update after refresh
        await MainActor.run {
            // This will trigger view refresh
        }
    }
    
    // MARK: - Timer Management
    func startPeriodicRefresh() {
        // Stop any existing timer first
        stopPeriodicRefresh()
        
        // Start new timer - refresh every AppConstants.MatchupRefresh seconds when view is active
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(AppConstants.MatchupRefresh), repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active && !viewModel.isLoading {
                    print("🔄 AUTO-REFRESH: Refreshing Mission Control data...")
                    await viewModel.manualRefresh()
                }
            }
        }
        
        print("🚀 TIMER: Started Mission Control auto-refresh (\(AppConstants.MatchupRefresh)s intervals)")
    }
    
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("🛑 TIMER: Stopped Mission Control auto-refresh")
    }
    
    func startCountdownTimer() {
        stopCountdownTimer()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            refreshCountdown -= 1.0
            
            if refreshCountdown <= 0 {
                refreshCountdown = Double(AppConstants.MatchupRefresh)
            }
        }
    }
    
    func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    // MARK: - Micro Mode Actions
    func handleMicroCardTap(_ cardId: String) {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            if expandedCardId == cardId {
                expandedCardId = nil
            } else {
                expandedCardId = cardId
            }
        }
    }
    
    // MARK: - Week Picker Actions
    func showWeekPicker() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        showingWeekPicker = true
    }
    
    func onWeekSelected(_ week: Int) {
        selectedWeek = week
        
        Task {
            await viewModel.loadMatchupsForWeek(week)
        }
    }
}