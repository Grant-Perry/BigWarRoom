//
//  AppLifecycleManager.swift
//  BigWarRoom
//
//  🔋 BATTERY FIX: Central service to manage app lifecycle state
//  Prevents background timers from draining battery
//

import Foundation
import SwiftUI
import Observation

/// Centralized manager for app lifecycle state
/// Allows services to pause/resume based on app being active or backgrounded
@Observable
@MainActor
final class AppLifecycleManager {
    
    // MARK: - Singleton
    static let shared = AppLifecycleManager()
    
    // MARK: - Observable Properties
    
    /// Is the app currently active (foreground)?
    var isActive: Bool = true
    
    /// Current scene phase
    var currentPhase: ScenePhase = .active
    
    // MARK: - Private Properties
    
    private var lastPhaseChange: Date = Date()
    
    /// Should the app prevent auto-lock when active?
    private var keepAppActiveEnabled: Bool = true
    
    // MARK: - Initialization
    
    private init() {
        // Load keep app active setting
        keepAppActiveEnabled = UserDefaults.standard.object(forKey: "keepAppActive") as? Bool ?? true
        
        DebugPrint(mode: .lifecycle, "🔋 AppLifecycleManager initialized")
        DebugPrint(mode: .lifecycle, "📱 Keep App Active: \(keepAppActiveEnabled ? "ENABLED" : "DISABLED")")
        
        // Set initial idle timer state
        updateIdleTimerState()
    }
    
    // MARK: - Public Methods
    
    /// Update the keep app active setting
    /// Called from SettingsViewModel when user toggles the setting
    func updateKeepAppActiveSetting(_ enabled: Bool) {
        keepAppActiveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "keepAppActive")
        
        DebugPrint(mode: .lifecycle, "📱 Keep App Active setting changed to: \(enabled ? "ENABLED" : "DISABLED")")
        
        // Update idle timer immediately
        updateIdleTimerState()
    }
    
    /// Update the current scene phase
    /// Called from the app's root view when scenePhase changes
    func updatePhase(_ newPhase: ScenePhase) {
        let oldPhase = currentPhase
        currentPhase = newPhase
        lastPhaseChange = Date()
        
        // Update active state
        isActive = (newPhase == .active)
        
        // Log phase changes
        logPhaseChange(from: oldPhase, to: newPhase)
        
        // Notify observers
        handlePhaseChange(from: oldPhase, to: newPhase)
    }
    
    // MARK: - Private Methods
    
    private func logPhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        let oldState = phaseDescription(oldPhase)
        let newState = phaseDescription(newPhase)
        
        DebugPrint(mode: .lifecycle, "🔋 App lifecycle changed: \(oldState) → \(newState)")
    }
    
    private func phaseDescription(_ phase: ScenePhase) -> String {
        switch phase {
        case .active:
            return "ACTIVE (foreground)"
        case .inactive:
            return "INACTIVE (transitioning)"
        case .background:
            return "BACKGROUND (suspended)"
        @unknown default:
            return "UNKNOWN"
        }
    }
    
    private func handlePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch (oldPhase, newPhase) {
        case (_, .background):
            // App went to background - pause everything
            DebugPrint(mode: .lifecycle, "🔋 PAUSING all timers and updates (background)")
            updateIdleTimerState()
            
        case (.background, .active):
            // App returned to foreground - resume everything
            DebugPrint(mode: .lifecycle, "🔋 RESUMING all timers and updates (foreground)")
            updateIdleTimerState()
            
        case (.inactive, .active):
            // Returned from inactive (e.g., Control Center closed)
            DebugPrint(mode: .lifecycle, "🔋 App returned to active from inactive")
            updateIdleTimerState()
            
        default:
            break
        }
    }
    
    // MARK: - Idle Timer Management
    
    /// Updates the idle timer state based on app phase, user setting, AND live games
    /// Only keeps screen awake when there are actually live games happening
    private func updateIdleTimerState() {
        // During initial app launch, SmartRefreshManager may not be ready yet
        // Default to false (allow auto-lock) until services are initialized
        let hasLiveGames = isServicesReady ? SmartRefreshManager.shared.hasLiveGames : false
        let shouldDisableIdleTimer = isActive && keepAppActiveEnabled && hasLiveGames
        
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = shouldDisableIdleTimer
        
        if shouldDisableIdleTimer {
            DebugPrint(mode: .lifecycle, "📱 Idle timer DISABLED - live games active, app will stay awake")
        } else if keepAppActiveEnabled && !hasLiveGames {
            DebugPrint(mode: .lifecycle, "📱 Idle timer ENABLED - no live games, allowing auto-lock")
        } else {
            DebugPrint(mode: .lifecycle, "📱 Idle timer ENABLED - normal auto-lock behavior")
        }
        #endif
    }
    
    /// Flag to track if dependent services are ready
    private var isServicesReady: Bool = false
    
    /// Called once services are initialized to enable full idle timer logic
    func markServicesReady() {
        isServicesReady = true
        DebugPrint(mode: .lifecycle, "📱 Services ready - updating idle timer state")
        updateIdleTimerState()
    }
    
    /// Call this when live game status changes to update idle timer
    func refreshIdleTimerForLiveGames() {
        updateIdleTimerState()
    }
}