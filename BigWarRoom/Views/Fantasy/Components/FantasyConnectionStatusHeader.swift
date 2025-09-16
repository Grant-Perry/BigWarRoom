//
//  FantasyConnectionStatusHeader.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Connection status header component
struct FantasyConnectionStatusHeader: View {
    let draftRoomViewModel: DraftRoomViewModel
    let fantasyViewModel: FantasyViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Only show connection status in debug mode
            if AppConstants.debug {
                if let connectedLeague = draftRoomViewModel.selectedLeagueWrapper {
                    connectedLeagueInfo(connectedLeague)
                } else {
                    noConnectionInfo
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func connectedLeagueInfo(_ connectedLeague: UnifiedLeagueManager.LeagueWrapper) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Source logo
                Group {
                    if connectedLeague.source == .sleeper {
                        AppConstants.sleeperLogo
                            .frame(width: 20, height: 20)
                    } else {
                        AppConstants.espnLogo
                            .frame(width: 20, height: 20)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        
                        Text("Connected to '\(connectedLeague.league.name)'")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    
                    Text("From War Room • \(connectedLeague.source.displayName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Auto-refresh toggle
                Button(action: {
                    fantasyViewModel.toggleAutoRefresh()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(fantasyViewModel.autoRefresh ? .green : .secondary)
                            .font(.system(size: 12))
                        
                        Text(fantasyViewModel.autoRefresh ? "ON" : "OFF")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(fantasyViewModel.autoRefresh ? .green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var noConnectionInfo: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                
                Text("No League Connected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            Text("Go to War Room to connect to a league first")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}