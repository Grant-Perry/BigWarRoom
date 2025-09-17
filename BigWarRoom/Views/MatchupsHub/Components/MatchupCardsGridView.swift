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
    let onShowDetail: (UnifiedMatchup) -> Void
    let onMicroCardTap: (String) -> Void
    let onExpandedCardDismiss: () -> Void
    let getWinningStatus: (UnifiedMatchup) -> Bool
    
    var body: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: gridSpacing
        ) {
            ForEach(sortedMatchups, id: \.id) { matchup in
                MatchupCardViewBuilder(
                    matchup: matchup,
                    microMode: microMode,
                    expandedCardId: expandedCardId,
                    isWinning: getWinningStatus(matchup),
                    onShowDetail: {
                        onShowDetail(matchup)
                    },
                    onMicroCardTap: onMicroCardTap,
                    dualViewMode: dualViewMode
                )
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
                onShowDetail: onShowDetail,
                onDismiss: onExpandedCardDismiss
            )
        )
    }
    
    // MARK: - Grid Configuration
    
    private var gridColumns: [GridItem] {
        if microMode {
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        } else if dualViewMode {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        } else {
            return [GridItem(.flexible(), spacing: 0)]
        }
    }
    
    private var gridSpacing: CGFloat {
        microMode ? 8 : (dualViewMode ? 16 : 12)
    }
}

/// Expanded card overlay component
struct ExpandedCardOverlayView: View {
    let expandedCardId: String?
    let sortedMatchups: [UnifiedMatchup]
    let getWinningStatus: (UnifiedMatchup) -> Bool
    let onShowDetail: (UnifiedMatchup) -> Void
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
            
            NonMicroCardView(
                matchup: expandedMatchup,
                isWinning: getWinningStatus(expandedMatchup)
            ) {
                onShowDetail(expandedMatchup)
            }
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