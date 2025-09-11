//
//  AsyncChoppedLeaderboardView.swift
//  BigWarRoom
//
//  Real-time Chopped league leaderboard with auto-refresh
//
// MARK: -> Real-Time Chopped Leaderboard

import SwiftUI

struct AsyncChoppedLeaderboardView: View {
    let leagueWrapper: UnifiedLeagueManager.LeagueWrapper
    let week: Int
    @ObservedObject var fantasyViewModel: FantasyViewModel
    @StateObject private var weekManager = WeekSelectionManager.shared
    
    var body: some View {
        Group {
            if fantasyViewModel.isLoadingChoppedData {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(1.5)
                    
                    Text("Loading Battle Royale Data...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if let choppedSummary = fantasyViewModel.currentChoppedSummary {
                ChoppedLeaderboardView(
                    choppedSummary: choppedSummary,
                    leagueName: leagueWrapper.league.name,
                    leagueID: leagueWrapper.league.leagueID // 🔥 NEW: Pass league ID for roster navigation
                )
                
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Pump the brakes...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    
                    Text("\nhave you even drafted yet?")
                        .font(.system(size: 16))
						.foregroundColor(.gpMinty)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadInitialChoppedData()
        }
        .onReceive(weekManager.$selectedWeek) { newWeek in
            // Reload data when week changes from WeekSelectionManager
            if newWeek != week {
                Task {
                    await loadChoppedData(for: newWeek)
                }
            }
        }
    }
    
    /// Load initial Chopped data on view appear
    private func loadInitialChoppedData() async {
        await loadChoppedData(for: week)
    }
    
    /// Load Chopped data for specific week
    private func loadChoppedData(for targetWeek: Int) async {
        fantasyViewModel.isLoadingChoppedData = true
        
        let summary = await fantasyViewModel.createRealChoppedSummaryWithHistory(
            leagueID: leagueWrapper.league.leagueID,
            week: targetWeek
        )
        
        fantasyViewModel.currentChoppedSummary = summary
        fantasyViewModel.isLoadingChoppedData = false
    }
}