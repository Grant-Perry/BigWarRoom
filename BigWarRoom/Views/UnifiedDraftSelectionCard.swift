//
//  UnifiedDraftSelectionCard.swift
//  BigWarRoom
//
//  Draft selection card supporting both Sleeper and ESPN leagues
//

import SwiftUI

struct UnifiedDraftSelectionCard: View {
    let leagueWrapper: UnifiedLeagueManager.LeagueWrapper
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var league: SleeperLeague {
        leagueWrapper.league
    }
    
    private var sourceColor: Color {
        switch leagueWrapper.source {
        case .sleeper:
            return .blue
        case .espn:
            return .red
        }
    }
    
    private var sourceIcon: String {
        switch leagueWrapper.source {
        case .sleeper:
            return "moon.fill"
        case .espn:
            return "sportscourt.fill"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Source indicator
                VStack(spacing: 4) {
                    switch leagueWrapper.source {
                    case .sleeper:
                        AppConstants.sleeperLogo
                    case .espn:
                        AppConstants.espnLogo
                    }
                }
                .frame(width: 60)
                
                // League info
                VStack(alignment: .leading, spacing: 6) {
                    // League name and status
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(league.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            // Add League ID display
                            Text("ID: \(league.leagueID)")
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .foregroundColor(Color.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Status badge
                        statusBadge
                    }
                    
                    // League details
                    HStack(spacing: 12) {
                        // Team count
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("\(league.totalRosters) teams")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Season
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(AppConstants.ESPNLeagueYear) // Use dynamic year instead of league.season
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Draft status
                        if league.draftID != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "target")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                
                                Text("Draft Ready")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                
                                Text("No Draft")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? sourceColor.opacity(0.15) : Color(.systemGray6).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? sourceColor : Color.clear,
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        let status = league.status
        
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusBackgroundColor)
            .foregroundColor(statusForegroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var statusBackgroundColor: Color {
        switch league.status {
        case .preDraft:
            return .orange.opacity(0.2)
        case .drafting:
            return .green.opacity(0.2)
        case .inSeason:
            return .blue.opacity(0.2)
        case .postSeason:
            return .purple.opacity(0.2)
        case .complete:
            return .gray.opacity(0.2)
        }
    }
    
    private var statusForegroundColor: Color {
        switch league.status {
        case .preDraft:
            return .orange
        case .drafting:
            return .green
        case .inSeason:
            return .blue
        case .postSeason:
            return .purple
        case .complete:
            return .gray
        }
    }
}