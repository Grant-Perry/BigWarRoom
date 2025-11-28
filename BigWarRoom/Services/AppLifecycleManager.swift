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
        
        logInfo("🔋 AppLifecycleManager initialized", category: "Lifecycle")
        logInfo("📱 Keep App Active: \(keepAppActiveEnabled ? "ENABLED" : "DISABLED")", category: "Lifecycle")
        
        // Set initial idle timer state
        updateIdleTimerState()
    }
    
    // MARK: - Public Methods
    
    /// Update the keep app active setting
    /// Called from SettingsViewModel when user toggles the setting
    func updateKeepAppActiveSetting(_ enabled: Bool) {
        keepAppActiveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "keepAppActive")
        
        logInfo("📱 Keep App Active setting changed to: \(enabled ? "ENABLED" : "DISABLED")", category: "Lifecycle")
        
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
        
        logInfo("🔋 App lifecycle changed: \(oldState) → \(newState)", category: "Lifecycle")
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
            logInfo("🔋 PAUSING all timers and updates (background)", category: "Lifecycle")
            updateIdleTimerState()
            
        case (.background, .active):
            // App returned to foreground - resume everything
            logInfo("🔋 RESUMING all timers and updates (foreground)", category: "Lifecycle")
            updateIdleTimerState()
            
        case (.inactive, .active):
            // Returned from inactive (e.g., Control Center closed)
            logInfo("🔋 App returned to active from inactive", category: "Lifecycle")
            updateIdleTimerState()
            
        default:
            break
        }
    }
    
    // MARK: - Idle Timer Management
    
    /// Updates the idle timer state based on app phase and user setting
    private func updateIdleTimerState() {
        let shouldDisableIdleTimer = isActive && keepAppActiveEnabled
        
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = shouldDisableIdleTimer
        
        if shouldDisableIdleTimer {
            logInfo("📱 Idle timer DISABLED - app will stay awake", category: "Lifecycle")
        } else {
            logInfo("📱 Idle timer ENABLED - normal auto-lock behavior", category: "Lifecycle")
        }
        #endif
    }
}