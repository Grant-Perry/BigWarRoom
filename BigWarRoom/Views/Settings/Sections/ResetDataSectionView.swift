//
//  ResetDataSectionView.swift
//  BigWarRoom
//
//  Reset data section component with clear actions
//

import SwiftUI

/// Component providing data clearing and reset functionality
struct ResetDataSectionView: View {
    let onClearCredentialsOnly: () -> Void
    let onClearCacheOnly: () -> Void
    let onClearAllData: () -> Void
    
    var body: some View {
        Section {
            // Individual clear actions
            ClearCredentialsButton(onClearCredentialsOnly: onClearCredentialsOnly)
            ClearCacheButton(onClearCacheOnly: onClearCacheOnly)
            
            Divider()
            
            // Nuclear option
            ClearAllDataButton(onClearAllData: onClearAllData)
        } header: {
            Text("Reset Sleeper Data")
        } footer: {
            Text("Clear specific Sleeper data or all Sleeper credentials and cached leagues.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Components

/// Clear credentials only button
private struct ClearCredentialsButton: View {
    let onClearCredentialsOnly: () -> Void
    
    var body: some View {
        Button("Clear Sleeper Credentials") {
            onClearCredentialsOnly()
        }
        .foregroundColor(.orange)
    }
}

/// Clear cache only button
private struct ClearCacheButton: View {
    let onClearCacheOnly: () -> Void
    
    var body: some View {
        Button("Clear Sleeper Cache") {
            onClearCacheOnly()
        }
        .foregroundColor(.orange)
    }
}

/// Clear all data button (destructive)
private struct ClearAllDataButton: View {
    let onClearAllData: () -> Void
    
    var body: some View {
        Button("Clear All Sleeper Data") {
            onClearAllData()
        }
        .foregroundColor(.red)
        .fontWeight(.bold)
    }
}