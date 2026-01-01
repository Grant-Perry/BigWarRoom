//
//  RefreshTimerService.swift
//  BigWarRoom
//
//  🔥 DRY REFACTOR: Now uses AsyncTaskService for consistent async patterns
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
    private let refreshInterval: TimeInterval
    private var onRefreshCallback: (() async -> Void)?
    
    // 🔥 DRY: Use AsyncTaskService for task management
    private let asyncTaskService = AsyncTaskService.shared
    
    // MARK: - Initialization
    
    // 🔥 PHASE 2.5: Default initializer for bridge pattern
    convenience init() {
        self.init(refreshInterval: Double(AppConstants.MatchupRefresh))
    }
    
    init(refreshInterval: TimeInterval) {
        self.refreshInterval = refreshInterval
        self.refreshCountdown = refreshInterval
    }
    
    deinit {
        // 🔥 DRY: Cancel tasks via AsyncTaskService
        asyncTaskService.cancel(id: "refresh_timer")
        asyncTaskService.cancel(id: "countdown_timer")
    }
    
    // MARK: - Public Interface
    
    /// Start periodic refresh with callback
    func startPeriodicRefresh(onRefresh: @escaping () async -> Void) {
        stopPeriodicRefresh()
        
        self.onRefreshCallback = onRefresh
        
        // 🔥 DRY: Use AsyncTaskService for periodic execution
        asyncTaskService.runPeriodically(
            id: "refresh_timer",
            interval: refreshInterval
        ) { @MainActor in
            // 🔋 BATTERY FIX: Only refresh if app is active
            if await AppLifecycleManager.shared.isActive {
                await onRefresh()
            }
        }
        
        isTimerActive = true
        startCountdownTimer()
    }
    
    /// Stop periodic refresh
    func stopPeriodicRefresh() {
        // 🔥 DRY: Cancel via AsyncTaskService
        asyncTaskService.cancel(id: "refresh_timer")
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
        
        // 🔥 DRY: Use AsyncTaskService for countdown
        asyncTaskService.runPeriodically(
            id: "countdown_timer",
            interval: 1.0
        ) { @MainActor [weak self] in
            guard let self = self else { return }
            
            // 🔋 BATTERY FIX: Only countdown if app is active
            if await AppLifecycleManager.shared.isActive {
                self.refreshCountdown -= 1.0
                
                if self.refreshCountdown <= 0 {
                    self.refreshCountdown = self.refreshInterval
                }
            }
        }
    }
    
    /// Stop countdown timer
    private func stopCountdownTimer() {
        // 🔥 DRY: Cancel via AsyncTaskService
        asyncTaskService.cancel(id: "countdown_timer")
    }
    
    /// Stop all timers
    func stopAllTimers() {
        stopPeriodicRefresh()
        stopCountdownTimer()
    }
}