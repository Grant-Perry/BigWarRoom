//
//  AsyncTaskService.swift
//  BigWarRoom
//
//  🔥 DRY CONSOLIDATION: Unified async task execution service
//  Eliminates ~40+ duplicate Task { @MainActor in } patterns
//  Provides centralized error handling, cancellation, retry, and debouncing
//

import Foundation
import SwiftUI

/// **Async Task Service**
/// **Centralized async task execution with consistent patterns**
@MainActor
final class AsyncTaskService {
    
    static let shared = AsyncTaskService()
    
    // Task storage for cancellation management
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var debounceTimers: [String: Task<Void, Never>] = [:]
    
    private init() {}
    
    // MARK: - Basic Task Execution
    
    /// Execute a simple async task with automatic MainActor dispatching
    func run(
        id: String? = nil,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        let taskID = id ?? UUID().uuidString
        
        // Cancel existing task with same ID
        activeTasks[taskID]?.cancel()
        
        let task = Task(priority: priority) { @MainActor in
            do {
                try await operation()
            } catch is CancellationError {
                // Silently handle cancellation
            } catch {
                // Log error but don't crash
                print("❌ AsyncTaskService error in task \(taskID): \(error.localizedDescription)")
            }
            
            // Remove from active tasks
            await MainActor.run {
                self.activeTasks.removeValue(forKey: taskID)
            }
        }
        
        activeTasks[taskID] = task
    }
    
    /// Execute task with loading state management
    func runWithLoading(
        id: String? = nil,
        loadingState: Binding<Bool>,
        errorMessage: Binding<String?> = .constant(nil),
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        let taskID = id ?? UUID().uuidString
        
        // Cancel existing task
        activeTasks[taskID]?.cancel()
        
        let task = Task { @MainActor in
            loadingState.wrappedValue = true
            errorMessage.wrappedValue = nil
            
            do {
                try await operation()
            } catch is CancellationError {
                // Silently handle cancellation
            } catch {
                errorMessage.wrappedValue = error.localizedDescription
                print("❌ AsyncTaskService error: \(error.localizedDescription)")
            }
            
            loadingState.wrappedValue = false
            
            // Remove from active tasks
            await MainActor.run {
                self.activeTasks.removeValue(forKey: taskID)
            }
        }
        
        activeTasks[taskID] = task
    }
    
    // MARK: - Debounced Execution
    
    /// Execute task after debounce delay (cancels previous if called again)
    func debounce(
        id: String,
        delay: TimeInterval = 0.5,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        // Cancel existing debounce timer
        debounceTimers[id]?.cancel()
        
        let task = Task(priority: priority) { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            do {
                try await operation()
            } catch is CancellationError {
                // Silently handle cancellation
            } catch {
                print("❌ AsyncTaskService debounced error: \(error.localizedDescription)")
            }
            
            // Remove timer
            await MainActor.run {
                self.debounceTimers.removeValue(forKey: id)
            }
        }
        
        debounceTimers[id] = task
    }
    
    // MARK: - Retry Logic
    
    /// Execute task with automatic retry on failure
    func runWithRetry(
        id: String? = nil,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        let taskID = id ?? UUID().uuidString
        
        // Cancel existing task
        activeTasks[taskID]?.cancel()
        
        let task = Task(priority: priority) { @MainActor in
            var attempt = 0
            var lastError: Error?
            
            while attempt < maxRetries {
                do {
                    try await operation()
                    // Success - break out
                    await MainActor.run {
                        self.activeTasks.removeValue(forKey: taskID)
                    }
                    return
                } catch is CancellationError {
                    // Don't retry cancellations
                    await MainActor.run {
                        self.activeTasks.removeValue(forKey: taskID)
                    }
                    return
                } catch {
                    lastError = error
                    attempt += 1
                    
                    if attempt < maxRetries {
                        print("⚠️ AsyncTaskService retry \(attempt)/\(maxRetries) for \(taskID)")
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    }
                }
            }
            
            // All retries failed
            if let error = lastError {
                print("❌ AsyncTaskService failed after \(maxRetries) retries: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                self.activeTasks.removeValue(forKey: taskID)
            }
        }
        
        activeTasks[taskID] = task
    }
    
    // MARK: - Parallel Execution
    
    /// Execute multiple tasks in parallel and wait for all to complete
    func runParallel(
        id: String? = nil,
        priority: TaskPriority = .userInitiated,
        _ operations: [@MainActor () async throws -> Void]
    ) async {
        let taskID = id ?? UUID().uuidString
        
        await withTaskGroup(of: Void.self) { group in
            for operation in operations {
                group.addTask(priority: priority) { @MainActor in
                    do {
                        try await operation()
                    } catch is CancellationError {
                        // Silently handle cancellation
                    } catch {
                        print("❌ AsyncTaskService parallel error: \(error.localizedDescription)")
                    }
                }
            }
            
            // Wait for all to complete
            await group.waitForAll()
        }
    }
    
    // MARK: - Task Cancellation
    
    /// Cancel specific task by ID
    /// 🔥 FIX: Make nonisolated so it can be called from deinit
    nonisolated func cancel(id: String) {
        Task { @MainActor in
            self.activeTasks[id]?.cancel()
            self.activeTasks.removeValue(forKey: id)
            
            self.debounceTimers[id]?.cancel()
            self.debounceTimers.removeValue(forKey: id)
        }
    }
    
    /// Cancel all active tasks
    /// 🔥 FIX: Make nonisolated so it can be called from deinit
    nonisolated func cancelAll() {
        Task { @MainActor in
            for (_, task) in self.activeTasks {
                task.cancel()
            }
            self.activeTasks.removeAll()
            
            for (_, timer) in self.debounceTimers {
                timer.cancel()
            }
            self.debounceTimers.removeAll()
        }
    }
    
    // MARK: - Periodic Execution
    
    /// Execute task periodically with interval
    func runPeriodically(
        id: String,
        interval: TimeInterval,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        // Cancel existing periodic task
        cancel(id: id)
        
        let task = Task(priority: priority) { @MainActor in
            while !Task.isCancelled {
                do {
                    try await operation()
                } catch is CancellationError {
                    break
                } catch {
                    print("❌ AsyncTaskService periodic error: \(error.localizedDescription)")
                }
                
                // Wait for next interval
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    break
                }
            }
            
            // Remove from active tasks
            await MainActor.run {
                self.activeTasks.removeValue(forKey: id)
            }
        }
        
        activeTasks[id] = task
    }
    
    // MARK: - Helper Properties
    
    /// Check if specific task is active
    func isActive(id: String) -> Bool {
        activeTasks[id] != nil
    }
    
    /// Count of active tasks
    var activeTaskCount: Int {
        activeTasks.count
    }
}

// MARK: - REMOVED: View Extensions moved to /Extensions/View+Extensions.swift

// MARK: - Observable Object Extension

extension ObservableObject where Self: AnyObject {
    /// Execute async task with automatic weak self capture
    func asyncTask(
        id: String? = nil,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @MainActor (Self) async throws -> Void
    ) {
        AsyncTaskService.shared.run(id: id, priority: priority) { @MainActor [weak self] in
            guard let self = self else { return }
            try await operation(self)
        }
    }
}