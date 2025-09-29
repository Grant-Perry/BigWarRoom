//
//  TeamRosterModels.swift
//  BigWarRoom
//
//  Shared models for team roster navigation and display
//

import Foundation

/// Helper struct for team roster sheet navigation with stable ID
struct TeamRosterSheetInfo: Identifiable {
    // 🔥 FIXED: Use teamCode as stable ID instead of UUID() to prevent loops
    var id: String { teamCode }
    let teamCode: String
}

/// Helper struct for team roster info (simplified)
struct TeamRosterInfo {
    let teamCode: String
    let teamName: String
}