//
//  CompactLeagueCard.swift
//  BigWarRoom
//
//  Gorgeous league selection card matching Fantasy league picker style
//

import SwiftUI

struct CompactLeagueCard: View {
    let leagueWrapper: UnifiedLeagueManager.LeagueWrapper
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var animateSelection = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Visual selection feedback
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                animateSelection = true
            }
            
            // Slight delay, then select
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onSelect()
            }
        }) {
            VStack(spacing: 12) {
                // Header with league name and team count badge
                VStack(spacing: 6) {
                    HStack {
                        Text(leagueWrapper.league.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Team count badge
                        Text("\(leagueWrapper.league.totalRosters) Teams")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                            )
                    }
                    
                    // League source badge
                    HStack {
                        // Source logo (15x15 like Fantasy picker)
                        Group {
                            if leagueWrapper.source == .sleeper {
                                AppConstants.sleeperLogo
                                    .frame(width: 15, height: 15)
                            } else {
                                AppConstants.espnLogo
                                    .frame(width: 15, height: 15)
                            }
                        }
                        
                        Text(leagueWrapper.source.rawValue.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Status indicator
                        if leagueWrapper.league.status == .drafting {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                
                                Text("DRAFTING")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action indicator
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .gpGreen)
                    
                    Text(isSelected ? "Selected" : "Select League")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .gpGreen)
                    
                    Spacer()
                }
            }
            .padding(16)
            .frame(height: 120) // Consistent height like Fantasy picker
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
            .scaleEffect(isSelected || animateSelection ? 1.05 : 1.0)
            .shadow(color: .black.opacity(isSelected ? 0.3 : 0.1), radius: isSelected ? 10 : 4, x: 0, y: isSelected ? 6 : 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animateSelection)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            animateSelection = false
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CompactLeagueCard(
            leagueWrapper: UnifiedLeagueManager.LeagueWrapper(
                id: "sleeper_test1",
                league: SleeperLeague(
                    leagueID: "test1",
                    name: "My Awesome Fantasy League",
                    status: .drafting,
                    sport: "nfl",
                    season: "2024",
                    seasonType: "regular",
                    totalRosters: 12,
                    draftID: "test_draft",
                    avatar: nil,
                    settings: nil,
                    scoringSettings: nil,
                    rosterPositions: nil
                ),
                source: .sleeper,
                client: SleeperAPIClient.shared
            ),
            isSelected: false,
            onSelect: {}
        )
        
        CompactLeagueCard(
            leagueWrapper: UnifiedLeagueManager.LeagueWrapper(
                id: "espn_test2",
                league: SleeperLeague(
                    leagueID: "test2",
                    name: "ESPN Championship League",
                    status: .complete,
                    sport: "nfl", 
                    season: "2024",
                    seasonType: "regular",
                    totalRosters: 10,
                    draftID: "espn_draft",
                    avatar: nil,
                    settings: nil,
                    scoringSettings: nil,
                    rosterPositions: nil
                ),
                source: .espn,
                client: ESPNAPIClient.shared
            ),
            isSelected: true,
            onSelect: {}
        )
    }
    .padding()
    .background(Color.black)
}