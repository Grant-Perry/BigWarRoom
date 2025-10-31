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
        // 🔥 NAVIGATION FIX: Don't reload if we already have matchups - prevents loading screen on navigation return
        guard matchupsHubViewModel.myMatchups.isEmpty else {
            return // Already have data, don't reload
        }
        
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
        
        // 🔥 DISABLED: Removed competing timer - MatchupsHubViewModel handles all auto-refresh
        // Only the ViewModel's master timer should control refreshing to prevent infinite loops
        // This View only manages the visual countdown timer now
        
        // refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(AppConstants.MatchupRefresh), repeats: true) { _ in
        //     Task { @MainActor in
        //         if UIApplication.shared.applicationState == .active && !matchupsHubViewModel.isLoading {
        //             await matchupsHubViewModel.manualRefresh()
        //         }
        //     }
        // }
        
        // Start the visual countdown timer only
        startCountdownTimer()
    }
    
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        stopCountdownTimer()
        stopJustMeModeTimer() // Clean up Just Me Mode timer as well
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
    
    // MARK: - Just Me Mode Timer Management
    private func startJustMeModeTimer() {
        stopJustMeModeTimer() // Clean up any existing timer
        
        // guard matchupsHubViewModel.microModeEnabled else { return }
        
        // justMeModeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
        //     Task { @MainActor in
        //         withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
        //             matchupsHubViewModel.justMeModeBannerVisible = false
        //         }
        //     }
        // }
    }
    
    func stopJustMeModeTimer() {
        justMeModeTimer?.invalidate()
        justMeModeTimer = nil
    }
    
    // MARK: - UI Animation Actions
    func handleMicroCardTap(_ cardId: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            if matchupsHubViewModel.expandedCardId == cardId {
                matchupsHubViewModel.expandedCardId = nil
            } else {
                matchupsHubViewModel.expandedCardId = cardId
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
    
    // 🏈 NAVIGATION FREEDOM: Remove showMatchupDetail - using NavigationLinks instead
    // func showMatchupDetail(_ matchup: UnifiedMatchup) {
    //     let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    //     impactFeedback.impactOccurred()
    //     
    //     showingMatchupDetail = matchup
    // }
    
    // MARK: - Week Selection Actions
    func onWeekSelected(_ week: Int) {
        Task {
            await matchupsHubViewModel.loadMatchupsForWeek(week)
            // Week change means we need to reload, so reset the flag to allow reload on next appear if needed
            // Actually, don't reset here - hasLoadedInitialData should only prevent reload when navigating back
            // Week changes are handled by onChange, which calls this directly
        }
    }
    
    // MARK: - Toggle Actions
    
    func toggleMicroMode() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            matchupsHubViewModel.microModeEnabled.toggle()
            if !matchupsHubViewModel.microModeEnabled {
                // When turning off Just Me mode, also collapse cards
                matchupsHubViewModel.expandedCardId = nil 
                // matchupsHubViewModel.justMeModeBannerVisible = false
                stopJustMeModeTimer() 
            } else {
                // When turning on Just Me mode, just enable it - no banner
                // matchupsHubViewModel.justMeModeBannerVisible = true
                // startJustMeModeTimer()
            }
        }
    }
    
    func toggleDualViewMode() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 🔥 FIXED: If in Just Me mode, exit Just Me and force single view
        if matchupsHubViewModel.microModeEnabled {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                // Exit Just Me mode
                matchupsHubViewModel.microModeEnabled = false
                matchupsHubViewModel.expandedCardId = nil
                matchupsHubViewModel.justMeModeBannerVisible = false
                stopJustMeModeTimer()
                
                // Force single view (not dual)
                dualViewMode = false
            }
        } else {
            // Normal toggle when not in Just Me mode
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                dualViewMode.toggle()
            }
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