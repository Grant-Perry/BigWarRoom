//
//  LeaguePickerOverlay.swift
//  BigWarRoom
//
//  Gorgeous league selection overlay for Fantasy view
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
                headerView
                
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
                footerView
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
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.gpGreen, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Choose Your League")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Text("Select a league to view detailed matchups")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                }
            }
            
            // Stats summary
            HStack(spacing: 20) {
                StatPill(
                    icon: "building.2.fill",
                    title: "Leagues",
                    value: "\(leagues.count)",
                    color: .blue
                )
                
                StatPill(
                    icon: "person.2.fill",
                    title: "Active",
                    value: "\(leagues.filter { !$0.isChoppedLeague }.count)",
                    color: .gpGreen
                )
                
                StatPill(
                    icon: "chart.bar.fill",
                    title: "Chopped",
                    value: "\(leagues.filter { $0.isChoppedLeague }.count)",
                    color: .purple
                )
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Footer
    private var footerView: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Tap any league to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
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
                        
                        leagueTypeBadge
                    }
                    
                    // League source badge
                    HStack {
                        sourceIcon
                        Spacer()
                    }
                }
                
                Spacer()
                
                // My team info
                if let myTeam = matchup.myTeam {
                    myTeamSection(myTeam)
                }
                
                // Current matchup preview
                matchupPreview
                
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
    
    private var leagueTypeBadge: some View {
        Text(matchup.isChoppedLeague ? "CHOPPED" : "\(league.totalRosters) Teams")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(matchup.isChoppedLeague ? Color.purple : Color.blue)
            )
    }
    
    private var sourceIcon: some View {
        HStack(spacing: 4) {
            // Use AppConstants logos at 15x15 size
            if matchup.league.source == .espn {
                AppConstants.espnLogo
                    .frame(width: 15, height: 15)
            } else {
                AppConstants.sleeperLogo  
                    .frame(width: 15, height: 15)
            }
            
            Text(matchup.league.source.rawValue.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private func myTeamSection(_ team: FantasyTeam) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("Your Team")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                Spacer()
                Text(String(format: "%.1f pts", team.currentScore ?? 0))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            HStack {
                Text(team.ownerName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                if let record = team.record {
                    Text("\(record.wins)-\(record.losses)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
        }
    }
    
    private var matchupPreview: some View {
        VStack(spacing: 4) {
            if matchup.isChoppedLeague {
                // Chopped league preview
                HStack {
                    Text("Rank")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    Spacer()
                    
                    if let ranking = matchup.myTeamRanking {
                        Text("#\(ranking.rank)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isSelected ? .white : .gpGreen)
                    }
                }
            } else {
                // Standard matchup preview
                if let opponent = matchup.opponentTeam {
                    HStack {
                        Text("vs \(opponent.ownerName)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", opponent.currentScore ?? 0))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Stat Pill Component
private struct StatPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    // Mock data for preview
    LeaguePickerOverlay(
        leagues: [],
        onLeagueSelected: { _ in },
        onDismiss: { }
    )
}
