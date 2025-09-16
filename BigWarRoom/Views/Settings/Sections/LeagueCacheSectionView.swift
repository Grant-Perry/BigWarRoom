//
//  LeagueCacheSectionView.swift
//  BigWarRoom
//
//  League cache section component displaying discovered leagues
//

import SwiftUI

/// Component for displaying cached league information and refresh controls
struct LeagueCacheSectionView: View {
    let hasValidCredentials: Bool
    let cachedLeagueCount: Int
    let onRefreshCache: () -> Void
    
    var body: some View {
        if hasValidCredentials && cachedLeagueCount > 0 {
            Section {
                CacheStatusRow(
                    cachedLeagueCount: cachedLeagueCount,
                    onRefreshCache: onRefreshCache
                )
                
                CacheDescription()
            } header: {
                Text("Discovered Leagues")
            } footer: {
                Text("Unlike ESPN, Sleeper automatically finds all your leagues - no manual entry required!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Supporting Components

/// Cache status row with refresh button
private struct CacheStatusRow: View {
    let cachedLeagueCount: Int
    let onRefreshCache: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.blue)
                Text("Cached Leagues: \(cachedLeagueCount)")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    onRefreshCache()
                }
                .font(.caption)
            }
            
            CacheDescription()
        }
    }
}

/// Cache description component
private struct CacheDescription: View {
    var body: some View {
        Text("Leagues auto-discovered from your Sleeper account")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}