//
//  RefreshTimerService.swift
//  BigWarRoom
//
//  Service for managing refresh timers and countdown logic
//

import Foundation
import SwiftUI
import Observation

/// Service responsible for managing refresh timers and countdown functionality
@Observable
@MainActor
final class RefreshTimerService {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: RefreshTimerService?
    
    static var shared: RefreshTimerService {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = RefreshTimerService()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: RefreshTimerService) {
        _shared = instance
    }
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var refreshCountdown: Double = 0
    var isTimerActive: Bool = false
    
    // MARK: - Private Properties
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private let refreshInterval: TimeInterval
    private var onRefreshCallback: (() async -> Void)?
    
    // MARK: - Initialization
    
    // 🔥 PHASE 2.5: Default initializer for bridge pattern
    convenience init() {
        self.init(refreshInterval: Double(AppConstants.MatchupRefresh))
    }
    
    init(refreshInterval: TimeInterval = Double(AppConstants.MatchupRefresh)) {
        self.refreshInterval = refreshInterval
        self.refreshCountdown = refreshInterval
    }
    
    deinit {
        Task { @MainActor in
            refreshTimer?.invalidate()
            refreshTimer = nil
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
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