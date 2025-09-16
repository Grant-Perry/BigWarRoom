//
//  DraftHeaderCardView.swift
//  BigWarRoom
//
//  Header card component displaying draft information and progress
//

import SwiftUI

/// Component for displaying draft header with progress tracking
struct DraftHeaderCardView: View {
    let league: SleeperLeague
    let totalPicksCount: Int
    let expectedTotalPicks: Int?
    let draftProgressPercentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(league.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        DraftStatusBadge(status: league.status)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(league.totalRosters) teams")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(league.season)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                PicksCountDisplay(totalPicksCount: totalPicksCount)
            }
            
            // Draft progress section
            if let expectedPicks = expectedTotalPicks {
                DraftProgressSection(
                    totalPicks: totalPicksCount,
                    expectedPicks: expectedPicks,
                    progressPercentage: draftProgressPercentage
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Components

/// Component for displaying draft status badge
private struct DraftStatusBadge: View {
    let status: SleeperLeagueStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(status == .complete ? .green : .blue)
    }
}

/// Component for displaying pick count
private struct PicksCountDisplay: View {
    let totalPicksCount: Int
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(totalPicksCount)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("picks made")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Component for draft progress visualization
private struct DraftProgressSection: View {
    let totalPicks: Int
    let expectedPicks: Int
    let progressPercentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 2)
            
            Text("\(totalPicks) of \(expectedPicks) picks completed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}