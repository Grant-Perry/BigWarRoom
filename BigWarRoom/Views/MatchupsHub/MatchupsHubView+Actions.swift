//
//  MatchupsHubView+Actions.swift
//  BigWarRoom
//
//  UI-focused action handlers for MatchupsHubView
//

import SwiftUI

// MARK: - UI Actions & Timer Management
extension MatchupsHubView {
    
    // MARK: - Data Loading Actions (Delegated to ViewModel)
    func loadInitialData() {
        Task {
            if weekManager.selectedWeek != weekManager.currentNFLWeek {
                await matchupsHubViewModel.loadMatchupsForWeek(weekManager.selectedWeek)
            } else {
                await matchupsHubViewModel.loadAllMatchups()
            }
        }
    }
    
    func handlePullToRefresh() async {
        refreshing = true
        await matchupsHubViewModel.manualRefresh()
        refreshing = false
        
        // Reset timer countdown after manual refresh
        resetCountdown()
    }
    
    // MARK: - Timer Management (Standard App Pattern)
    func startPeriodicRefresh() {
        guard matchupsHubViewModel.autoRefreshEnabled else { return }
        stopPeriodicRefresh()
        
        // Start the actual refresh timer (every AppConstants.MatchupRefresh seconds)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(AppConstants.MatchupRefresh), repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active && !matchupsHubViewModel.isLoading {
                    await matchupsHubViewModel.manualRefresh()
                }
            }
        }
        
        // Start the visual countdown timer
        startCountdownTimer()
    }
    
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        stopCountdownTimer()
    }
    
    private func startCountdownTimer() {
        resetCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if refreshCountdown > 0 {
                refreshCountdown -= 1
            } else {
                resetCountdown()
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func resetCountdown() {
        refreshCountdown = Double(AppConstants.MatchupRefresh)
    }
    
    // MARK: - UI Animation Actions
    func handleMicroCardTap(_ cardId: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            if expandedCardId == cardId {
                expandedCardId = nil
            } else {
                expandedCardId = cardId
            }
        }
    }
    
    // MARK: - Navigation Actions
    func showWeekPicker() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        showingWeekPicker = true
    }
    
    func showSettings() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        showingSettings = true
    }
    
    func showMatchupDetail(_ matchup: UnifiedMatchup) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        showingMatchupDetail = matchup
    }
    
    // MARK: - Week Selection Actions
    func onWeekSelected(_ week: Int) {
        Task {
            await matchupsHubViewModel.loadMatchupsForWeek(week)
        }
    }
    
    // MARK: - Toggle Actions
    func toggleAutoRefresh() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        matchupsHubViewModel.toggleAutoRefresh()
        
        if matchupsHubViewModel.autoRefreshEnabled {
            startPeriodicRefresh()
        } else {
            stopPeriodicRefresh()
        }
    }
    
    func toggleMicroMode() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            microMode.toggle()
            if !microMode {
                expandedCardId = nil // Collapse any expanded cards when exiting micro mode
            }
        }
    }
    
    func toggleDualViewMode() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            dualViewMode.toggle()
        }
    }
    
    func toggleBattlesSection() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            battlesMinimized.toggle()
        }
    }
    
    func toggleSortOrder() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            sortByWinning.toggle()
        }
    }
}