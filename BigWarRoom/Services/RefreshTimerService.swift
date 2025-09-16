//
//  RefreshTimerService.swift
//  BigWarRoom
//
//  Service for managing refresh timers and countdown logic
//

import Foundation
import SwiftUI
import Combine

/// Service responsible for managing refresh timers and countdown functionality
@MainActor
final class RefreshTimerService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var refreshCountdown: Double = 0
    @Published var isTimerActive: Bool = false
    
    // MARK: - Private Properties
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private let refreshInterval: TimeInterval
    private var onRefreshCallback: (() async -> Void)?
    
    // MARK: - Initialization
    init(refreshInterval: TimeInterval = Double(AppConstants.MatchupRefresh)) {
        self.refreshInterval = refreshInterval
        self.refreshCountdown = refreshInterval
    }
    
    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    // MARK: - Public Interface
    
    /// Start periodic refresh with callback
    func startPeriodicRefresh(onRefresh: @escaping () async -> Void) {
        stopPeriodicRefresh()
        
        self.onRefreshCallback = onRefresh
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active {
                    await onRefresh()
                }
            }
        }
        
        isTimerActive = true
        startCountdownTimer()
    }
    
    /// Stop periodic refresh
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        onRefreshCallback = nil
        isTimerActive = false
        stopCountdownTimer()
    }
    
    /// Reset countdown timer (typically called after manual refresh)
    func resetCountdown() {
        refreshCountdown = refreshInterval
    }
    
    /// Start countdown timer
    private func startCountdownTimer() {
        stopCountdownTimer()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.refreshCountdown -= 1.0
                
                if self.refreshCountdown <= 0 {
                    self.refreshCountdown = self.refreshInterval
                }
            }
        }
    }
    
    /// Stop countdown timer
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    /// Stop all timers
    func stopAllTimers() {
        stopPeriodicRefresh()
        stopCountdownTimer()
    }
}