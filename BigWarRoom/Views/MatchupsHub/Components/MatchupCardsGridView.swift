//
//  MatchupCardsGridView.swift
//  BigWarRoom
//
//  Matchup cards grid component with overlay support
//

import SwiftUI

/// Grid component displaying matchup cards with dynamic layout and overlay
struct MatchupCardsGridView: View {
    let sortedMatchups: [UnifiedMatchup]
    let microMode: Bool
    let dualViewMode: Bool
    let expandedCardId: String?
    let onMicroCardTap: (String) -> Void
    let onExpandedCardDismiss: () -> Void
    let getWinningStatus: (UnifiedMatchup) -> Bool
    let getOptimizationStatus: (UnifiedMatchup) -> Bool
    
    // 🔥 NEW: All matchups (before filtering) to pass to detail views for horizontal scrolling
    let allMatchups: [UnifiedMatchup]
    
    // 🔥 NEW: Bar-style layout toggle
    @AppStorage("MatchupsHub_UseBarLayout") private var useBarLayout = false
    
    // 🔥 NEW: Helper to get matchups from the same league for swiping
    private func getLeagueMatchups(for matchup: UnifiedMatchup) -> [UnifiedMatchup] {
        // 🔥 FIX: If this matchup already has all league matchups stored, use those
        if let storedMatchups = matchup.allLeagueMatchups, !storedMatchups.isEmpty {
            // Convert FantasyMatchup array to UnifiedMatchup array
            return storedMatchups.map { fantasyMatchup in
                UnifiedMatchup(
                    id: "\(matchup.league.id)_\(fantasyMatchup.id)",
                    league: matchup.league,
                    fantasyMatchup: fantasyMatchup,
                    choppedSummary: nil,
                    lastUpdated: matchup.lastUpdated,
                    myTeamRanking: nil,
                    myIdentifiedTeamID: matchup.myIdentifiedTeamID,
                    authenticatedUsername: "" // Not needed for display
                )
            }
        }
        
        // Fallback to old logic
        // 1. Filter to same league
        let sameLeague = allMatchups.filter { $0.league.id == matchup.league.id }
        
        // 2. If this is an eliminated matchup, include YOUR matchup + only ACTIVE playoff matchups
        if matchup.isMyManagerEliminated {
            // Get all active (non-eliminated) matchups from this league
            let activeMatchups = sameLeague.filter { !$0.isMyManagerEliminated }
            
            // Always include YOUR matchup first, then the active ones
            return [matchup] + activeMatchups
        }
        
        // 3. For non-eliminated, show all matchups from this league
        return sameLeague
    }
    
    var body: some View {
        Group {
            // 🔥 NEW: Handle empty matchups with a friendly message
            if sortedMatchups.isEmpty {
                NoMatchupsThisWeekView()
            } else if useBarLayout && !microMode {
                // 🔥 NEW: Bar-style layout (single column only)
                ScrollView {
                    LazyVStack(spacing: 40) {
                        ForEach(sortedMatchups, id: \.id) { matchup in
                            NavigationLink(destination: MatchupDetailSheetsView(
                                matchup: matchup,
                                allLeagueMatchups: getLeagueMatchups(for: matchup)
                            )) {
                                MatchupBarCardView(
                                    matchup: matchup,
                                    isWinning: getWinningStatus(matchup),
                                    isLineupOptimized: getOptimizationStatus(matchup)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
            } else {
                // Original grid layouts
                if microMode {
                    // Micro cards - 4 columns with more top padding
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                        spacing: 44
                    ) {
                        ForEach(sortedMatchups, id: \.id) { matchup in
                            NavigationLink(destination: MatchupDetailSheetsView(
                                matchup: matchup,
                                allLeagueMatchups: getLeagueMatchups(for: matchup)
                            )) {
                                MatchupCardViewBuilder(
                                    matchup: matchup,
                                    microMode: true,
                                    expandedCardId: expandedCardId,
                                    isWinning: getWinningStatus(matchup),
                                    onMicroCardTap: onMicroCardTap,
                                    dualViewMode: dualViewMode,
                                    isLineupOptimized: getOptimizationStatus(matchup)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 20)
                } else if dualViewMode {
                    // 🔥 BULLETPROOF: Dead simple 2-column grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 20),
                            GridItem(.flexible(), spacing: 20)
                        ],
                        spacing: 40
                    ) {
                        ForEach(sortedMatchups, id: \.id) { matchup in
                            NavigationLink(destination: MatchupDetailSheetsView(
                                matchup: matchup,
                                allLeagueMatchups: getLeagueMatchups(for: matchup)
                            )) {
                                MatchupCardViewBuilder(
                                    matchup: matchup,
                                    microMode: false,
                                    expandedCardId: expandedCardId,
                                    isWinning: getWinningStatus(matchup),
                                    onMicroCardTap: onMicroCardTap,
                                    dualViewMode: true,
                                    isLineupOptimized: getOptimizationStatus(matchup)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } else {
                    // Single column view
                    LazyVGrid(
                        columns: [GridItem(.flexible())],
                        spacing: 40
                    ) {
                        ForEach(sortedMatchups, id: \.id) { matchup in
                            NavigationLink(destination: MatchupDetailSheetsView(
                                matchup: matchup,
                                allLeagueMatchups: getLeagueMatchups(for: matchup)
                            )) {
                                MatchupCardViewBuilder(
                                    matchup: matchup,
                                    microMode: false,
                                    expandedCardId: expandedCardId,
                                    isWinning: getWinningStatus(matchup),
                                    onMicroCardTap: onMicroCardTap,
                                    dualViewMode: false,
                                    isLineupOptimized: getOptimizationStatus(matchup)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, useBarLayout ? 0 : 44)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: microMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expandedCardId)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dualViewMode)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: useBarLayout)
        .overlay(
            // Only show overlay for non-bar layouts
            Group {
                if !useBarLayout {
                    ExpandedCardOverlayView(
                        expandedCardId: expandedCardId,
                        sortedMatchups: sortedMatchups,
                        getWinningStatus: getWinningStatus,
                        onDismiss: onExpandedCardDismiss,
                        getOptimizationStatus: getOptimizationStatus,
                        allMatchups: allMatchups
                    )
                }
            }
        )
    }
}

/// Expanded card overlay component
struct ExpandedCardOverlayView: View {
    let expandedCardId: String?
    let sortedMatchups: [UnifiedMatchup]
    let getWinningStatus: (UnifiedMatchup) -> Bool
    // 🏈 NAVIGATION FREEDOM: Remove callback - NavigationLink handles tap
    // let onShowDetail: (UnifiedMatchup) -> Void
    let onDismiss: () -> Void
    let getOptimizationStatus: (UnifiedMatchup) -> Bool  // 💊 RX: Get optimization status
    
    // 🔥 NEW: All matchups for league filtering
    let allMatchups: [UnifiedMatchup]
    
    // 🔥 NEW: Helper to get league matchups
    private func getLeagueMatchups(for matchup: UnifiedMatchup) -> [UnifiedMatchup] {
        let sameLeague = allMatchups.filter { $0.league.id == matchup.league.id }
        
        if matchup.isMyManagerEliminated {
            // Get all active (non-eliminated) matchups from this league
            let activeMatchups = sameLeague.filter { !$0.isMyManagerEliminated }
            
            // Always include YOUR matchup first, then the active ones
            return [matchup] + activeMatchups
        }
        
        return sameLeague
    }
    
    var body: some View {
        if let expandedId = expandedCardId,
           let expandedMatchup = sortedMatchups.first(where: { $0.id == expandedId }) {
            
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        onDismiss()
                    }
                }
            
            NavigationLink(destination: MatchupDetailSheetsView(
                matchup: expandedMatchup,
                allLeagueMatchups: getLeagueMatchups(for: expandedMatchup)
            )) {
                NonMicroCardView(
                    matchup: expandedMatchup,
                    isWinning: getWinningStatus(expandedMatchup),
                    // 🏈 NAVIGATION FREEDOM: Remove onTap parameter - NavigationLink handles navigation
                    // onTap: { },
                    dualViewMode: true,
                    isLineupOptimized: getOptimizationStatus(expandedMatchup)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: UIScreen.main.bounds.width * 0.6, height: 205)
            .overlay(expandedCardBorder)
            .zIndex(1000)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    onDismiss()
                }
            }
        }
    }
    
    // MARK: - Expanded Card Styling
    
    private var expandedCardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: [.gpGreen, .blue, .gpGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
    }
}

// MARK: - No Matchups This Week View

/// Friendly message when user has services connected but no matchups
struct NoMatchupsThisWeekView: View {
    @State private var weekManager = WeekSelectionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "calendar.circle")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 8) {
                    Text("Loading matchups for this week...")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Week \(weekManager.selectedWeek)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                
                VStack(spacing: 4) {
                    Text("Your leagues might be:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 2) {
                        Text("• Not active yet for this week")
                        Text("• Finished for the season")
                        Text("• On a bye week")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                }
            }
            
            HStack(spacing: 12) {
                // Quick week navigation
                if weekManager.selectedWeek > 1 {
                    Button("← Week \(weekManager.selectedWeek - 1)") {
                        weekManager.selectWeek(weekManager.selectedWeek - 1)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if weekManager.selectedWeek < 18 {
                    Button("Week \(weekManager.selectedWeek + 1) →") {
                        weekManager.selectWeek(weekManager.selectedWeek + 1)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(40)
        .multilineTextAlignment(.center)
    }
}