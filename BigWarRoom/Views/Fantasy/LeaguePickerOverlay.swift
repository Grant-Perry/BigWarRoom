//
//  LeaguePickerOverlay.swift
//  BigWarRoom
//
//  Gorgeous league selection overlay for Fantasy view - CLEAN ARCHITECTURE
//

import SwiftUI

struct LeaguePickerOverlay: View {
    let leagues: [UnifiedMatchup]
    let onLeagueSelected: (UnifiedLeagueManager.LeagueWrapper) -> Void
    let onDismiss: () -> Void
    
    @State private var animateIn = false
    @State private var selectedIndex: Int?
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 24) {
                // Header
                buildHeaderView()
                
                // League Cards
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(leagues.enumerated()), id: \.element.id) { index, matchup in
                            LeagueSelectionCard(
                                matchup: matchup,
                                index: index,
                                isSelected: selectedIndex == index,
                                animateIn: animateIn
                            ) {
                                selectLeague(matchup, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                
                // Footer
                buildFooterView()
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.8)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground),
                                Color(.systemGray6).opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 16)
            .scaleEffect(animateIn ? 1.0 : 0.85)
            .opacity(animateIn ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
        }
        .onAppear {
            animateIn = true
        }
    }
    
    // MARK: - Builder Functions (NO COMPUTED VIEW PROPERTIES)
    
    func buildHeaderView() -> some View {
        LeaguePickerOverlayHeaderView(leagues: leagues, onDismiss: onDismiss)
    }
    
    func buildFooterView() -> some View {
        LeaguePickerOverlayFooterView(onDismiss: onDismiss)
    }
    
    // MARK: - Actions
    private func selectLeague(_ matchup: UnifiedMatchup, index: Int) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Visual selection feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedIndex = index
        }
        
        // Delay for animation, then select
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onLeagueSelected(matchup.league)
        }
    }
}

// MARK: - League Selection Card
private struct LeagueSelectionCard: View {
    let matchup: UnifiedMatchup
    let index: Int
    let isSelected: Bool
    let animateIn: Bool
    let onTap: () -> Void
    
    private var league: SleeperLeague { matchup.league.league }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header with league name and type
                VStack(spacing: 6) {
                    HStack {
                        Text(league.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        buildLeagueTypeBadge()
                    }
                    
                    // League source badge
                    HStack {
                        buildSourceIcon()
                        Spacer()
                    }
                }
                
                Spacer()
                
                // My team info
                if let myTeam = matchup.myTeam {
                    buildMyTeamSection(myTeam)
                }
                
                // Current matchup preview
                buildMatchupPreview()
                
                // Action indicator
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .gpGreen)
                    
                    Text("View Details")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .gpGreen)
                    
                    Spacer()
                }
            }
            .padding(16)
            .frame(height: 180)
            .background(
                ZStack {
                    // Main background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isSelected ?
                            LinearGradient(colors: [.gpGreen, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                        )
                    
                    // Glow effect when selected
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.green.opacity(0.3))
                            .blur(radius: 8)
                            .scaleEffect(1.1)
                    }
                    
                    // Border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ?
                            LinearGradient(colors: [.white.opacity(0.6)], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(color: .black.opacity(isSelected ? 0.3 : 0.1), radius: isSelected ? 10 : 4, x: 0, y: isSelected ? 6 : 2)
            .offset(y: animateIn ? 0 : 50)
            .opacity(animateIn ? 1 : 0)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(Double(index) * 0.1),
                value: animateIn
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Builder Functions
    
    func buildLeagueTypeBadge() -> some View {
        LeagueSelectionCardTypeBadgeView(matchup: matchup)
    }
    
    func buildSourceIcon() -> some View {
        LeagueSelectionCardSourceIconView(matchup: matchup)
    }
    
    func buildMyTeamSection(_ team: FantasyTeam) -> some View {
        LeagueSelectionCardMyTeamView(team: team, isSelected: isSelected)
    }
    
    func buildMatchupPreview() -> some View {
        LeagueSelectionCardMatchupPreviewView(matchup: matchup, isSelected: isSelected)
    }
}