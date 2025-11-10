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
    // 🏈 NAVIGATION FREEDOM: Remove callback - using NavigationLinks instead
    // let onShowDetail: (UnifiedMatchup) -> Void
    let onMicroCardTap: (String) -> Void
    let onExpandedCardDismiss: () -> Void
    let getWinningStatus: (UnifiedMatchup) -> Bool
    
    var body: some View {
        Group {
            // 🔥 NEW: Handle empty matchups with a friendly message
            if sortedMatchups.isEmpty {
                NoMatchupsThisWeekView()
            } else {
                // 🔥 NUCLEAR REBUILD: Simple, bulletproof grid
                if microMode {
                    // Micro cards - 4 columns
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
                        spacing: 50 // Micro cards keep 50pt spacing
                    ) {
                        ForEach(sortedMatchups, id: \.id) { matchup in
                            MatchupCardViewBuilder(
                                matchup: matchup,
                                microMode: true,
                                expandedCardId: expandedCardId,
                                isWinning: getWinningStatus(matchup),
                                onMicroCardTap: onMicroCardTap,
                                dualViewMode: dualViewMode
                            )
                        }
                    }
                } else if dualViewMode {
                    // 🔥 BULLETPROOF: Dead simple 2-column grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 70  // 🔥 INCREASED: Max spacing for NonMicro dual view
                    ) {
                        ForEach(sortedMatchups, id: \.id) { matchup in
                            MatchupCardViewBuilder(
                                matchup: matchup,
                                microMode: false,
                                expandedCardId: expandedCardId,
                                isWinning: getWinningStatus(matchup),
                                onMicroCardTap: onMicroCardTap,
                                dualViewMode: true
                            )
                        }
                    }
                } else {
                    // Single column view
                    LazyVGrid(
                        columns: [GridItem(.flexible())],
                        spacing: 76 // Spacing between Matchup cards on Mission Control
                    ) {
                        ForEach(sortedMatchups, id: \.id) { matchup in
                            MatchupCardViewBuilder(
                                matchup: matchup,
                                microMode: false,
                                expandedCardId: expandedCardId,
                                isWinning: getWinningStatus(matchup),
                                onMicroCardTap: onMicroCardTap,
                                dualViewMode: false
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24) // Increased from 20 to 24 to prevent edge clipping
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: microMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expandedCardId)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dualViewMode)
        .overlay(
            ExpandedCardOverlayView(
                expandedCardId: expandedCardId,
                sortedMatchups: sortedMatchups,
                getWinningStatus: getWinningStatus,
                // 🏈 NAVIGATION FREEDOM: Remove callback - NavigationLink handles tap
                // onShowDetail: onShowDetail,
                onDismiss: onExpandedCardDismiss
            )
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
            
            NavigationLink(destination: MatchupDetailSheetsView(matchup: expandedMatchup)) {
                NonMicroCardView(
                    matchup: expandedMatchup,
                    isWinning: getWinningStatus(expandedMatchup),
                    // 🏈 NAVIGATION FREEDOM: Remove onTap parameter - NavigationLink handles navigation
                    // onTap: { },
                    dualViewMode: true
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
                    Text("No Matchups This Week")
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
