// MARK: - REMOVED: DebugLogger.swift has been replaced by DebugPrint.swift
// This file only exists for backwards compatibility during migration.
// All DebugLogger calls should be replaced with DebugPrint() calls.

import Foundation

// Temporary compatibility enum - does nothing, prevents compile errors
enum DebugLogger {
    static func scoring(_ message: String, level: LogLevel = .debug) {}
    static func fantasy(_ message: String, level: LogLevel = .debug) {}
    static func playerIDMapping(_ message: String, level: LogLevel = .debug) {}
    static func draft(_ message: String, level: LogLevel = .debug) {}
    static func api(_ message: String, level: LogLevel = .debug) {}
    static func error(_ message: String, category: DebugCategory = .general) {}
    static func warning(_ message: String, category: DebugCategory = .general) {}
    
    enum LogLevel {
        case debug, info, warning, error
    }
    
    enum DebugCategory {
        case general, api, draft, fantasy, scoring, playerIDMapping
    }
}