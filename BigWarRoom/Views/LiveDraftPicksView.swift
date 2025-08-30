//
//  LiveDraftPicksView.swift
//  BigWarRoom
//
//  Live draft picks feed in its own dedicated tab
//

import SwiftUI

struct LiveDraftPicksView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header Info
                    if viewModel.selectedDraft != nil || viewModel.isConnectedToManualDraft {
                        headerCard
                    }
                    
                    // Live Picks Content
                    if viewModel.allDraftPicks.isEmpty {
                        emptyStateView
                    } else {
                        liveDraftPicksGrid
                    }
                }
                .padding()
            }
            .navigationTitle("Live Draft Picks")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await viewModel.forceRefresh()
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wifi.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    if let selectedDraft = viewModel.selectedDraft {
                        Text(selectedDraft.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Add League ID display
                        Text("League ID: \(selectedDraft.leagueID)")
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                        
                        if let draftID = selectedDraft.draftID {
                            Text("Draft ID: \(String(draftID.suffix(12)))")
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Manual Draft")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Pick count and countdown
                VStack(alignment: .trailing, spacing: 4) {
                    if !viewModel.allDraftPicks.isEmpty {
                        Text("\(viewModel.allDraftPicks.count) picks made")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    // Polling countdown if active
                    if viewModel.isLiveMode {
                        PollingCountdownDial(
                            countdown: viewModel.pollingCountdown,
                            maxInterval: viewModel.maxPollingInterval,
                            isPolling: viewModel.connectionStatus == .connected,
                            onRefresh: {
                                Task {
                                    await viewModel.forceRefresh()
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Waiting for draft picks...")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Picks will appear here as they happen in real-time")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if viewModel.selectedDraft == nil && !viewModel.isConnectedToManualDraft {
                VStack(spacing: 8) {
                    Text("Connect to a draft in the War Room tab")
                        .font(.callout)
                        .foregroundColor(.blue)
                    
                    Button("Go to War Room") {
                        // This would require TabView selection binding
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Live Draft Picks Grid
    
    private var liveDraftPicksGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Recent picks indicator
            if !viewModel.recentLivePicks.isEmpty {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text("Recent picks highlighted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            // Picks grid - 3 columns for better density
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3) // 3 columns as requested
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.allDraftPicks.reversed()) { pick in // Most recent first
                    DraftPickCard(
                        pick: pick,
                        isRecent: viewModel.recentLivePicks.contains { $0.playerID == pick.player.playerID },
                        myRosterID: viewModel.myRosterID,
                        isUsingPositionalLogic: viewModel.isUsingPositionalLogic,
                        teamCount: viewModel.currentDraftTeamCount
                    )
                }
            }
        }
    }
}

#Preview {
    LiveDraftPicksView(viewModel: DraftRoomViewModel())
}