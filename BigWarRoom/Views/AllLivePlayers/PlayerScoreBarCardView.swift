//
//  PlayerScoreBarCardView.swift
//  BigWarRoom
//
//  Seamless player card with animated score bar integration
//

import SwiftUI

struct PlayerScoreBarCardView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let animateIn: Bool
    let onTap: (() -> Void)?
    
    @State private var scoreBarWidth: Double = 0.0
    @State private var cardOffset: Double = 50.0
    @State private var cardOpacity: Double = 0.0
    
    private let maxScoreBarWidth: Double = 120.0 // Maximum width in points
    private let cardHeight: Double = 60.0 // Shorter card height (was 70)
    private let scoreBarHeight: Double = 20.0 // Shorter score bar (was 23.3)
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            // Just the player card - no separate scoreBar
            playerCardView
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            // LIVE border around the entire card
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    playerEntry.player.isLive ? 
                        LinearGradient(colors: [.blue, .gpGreen], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.gpYellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: playerEntry.player.isLive ? 3 : 2
                )
                .opacity(playerEntry.player.isLive ? 0.8 : 0.6)
        )
        .offset(y: animateIn ? cardOffset : 0)
        .opacity(animateIn ? cardOpacity : 1.0)
        .onAppear {
            if animateIn {
                // Animate card entrance first
                withAnimation(.easeOut(duration: 0.5)) {
                    cardOffset = 0.0
                    cardOpacity = 1.0
                }
                
                // Animate score bar from left to right after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        scoreBarWidth = playerEntry.scoreBarWidth
                    }
                }
            } else {
                // If not animating in, set final state immediately
                scoreBarWidth = playerEntry.scoreBarWidth
            }
        }
        .onChange(of: playerEntry.scoreBarWidth) { _, newWidth in
            // Smooth animation when scores update (left to right growth)
            withAnimation(.easeInOut(duration: 0.6)) {
                scoreBarWidth = newWidth
            }
        }
    }
    
    // MARK: - Player Card View
    
    private var playerCardView: some View {
        ZStack(alignment: .leading) {
            // Build the card content first (without image)
            HStack(spacing: 0) {
                // Empty space for where image will be overlaid
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 65) // Space for image
                
                // Player info
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        // Player name and position - with proper period formatting
                        Text(formattedPlayerName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Position badge
                        positionBadge
                        
                        // Team logo
                        teamLogoView
                        
                        Spacer()
                    }
                    
                    // Score and league info
                    HStack(spacing: 8) {
                        Text(playerEntry.currentScoreString)
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundColor(playerScoreColor)
                        
                        Text("pts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // League banner
                        leagueBanner
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(teamBackgroundView)
            
            // NOW overlay the player image on top - unconstrained!
            HStack {
                playerImageView
                    .offset(x: -10) // Move right instead of left (was x: -15)
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip the entire thing
    }
    
    // MARK: - Subviews
    
    private var playerImageView: some View {
        AsyncImage(url: playerEntry.player.headshotURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            playerFallbackView
        }
        .frame(width: 80, height: 100) // Bigger and taller - now unconstrained by card layout!
    }
    
    private var playerFallbackView: some View {
        Rectangle()
            .fill(teamGradient)
            .overlay(
                Text(playerEntry.player.firstName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private var positionBadge: some View {
        Text(playerEntry.position)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var teamLogoView: some View {
        Group {
            if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                TeamAssetManager.shared.logoOrFallback(for: team.id)
                    .frame(width: 20, height: 20) // Smaller logo (was 24x24)
            } else {
                Circle()
                    .fill(.gray)
                    .frame(width: 20, height: 20) // Smaller fallback
            }
        }
    }
    
    private var leagueBanner: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(leagueSourceColor)
                .frame(width: 6, height: 6)
            
            Text(playerEntry.leagueName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(2) // Allow 2 lines instead of 1
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(leagueSourceColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
    
    private var teamBackgroundView: some View {
        ZStack {
            // Base animated scoreBar
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.clear, scoreBarColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: max(
                                (UIScreen.main.bounds.width - 32) * 0.15, // Minimum 15% width
                                (UIScreen.main.bounds.width - 32) * scoreBarWidth
                            ))
                        
                        Spacer()
                    }
                )
            
            // Team-specific background overlay
            Group {
                if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(team.backgroundColor.opacity(0.1))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                }
            }
            
            HStack {
                Spacer()
                VStack {
                    performanceIndicator
                    Spacer()
                }
                .padding(.trailing, 8)
                .padding(.top, 6)
            }
        }
    }
    
    private var performanceIndicator: some View {
        let percentage = playerEntry.scoreBarWidth
        let color: Color = {
            if percentage >= 0.8 { return .gpGreen }
            else if percentage >= 0.5 { return .blue }
            else if percentage >= 0.25 { return .orange }
            else { return .red }
        }()
        
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(0.7)
    }
    
    private var scoreBarColor: Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen.opacity(0.5) }
        else if percentage >= 0.5 { return .blue.opacity(0.4) }
        else if percentage >= 0.25 { return .orange.opacity(0.4) }
        else { return .red.opacity(0.3) }
    }
    
    private var positionColor: Color {
        switch playerEntry.position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
    
    private var leagueSourceColor: Color {
        switch playerEntry.leagueSource {
        case "Sleeper": return .blue
        case "ESPN": return .red
        default: return .gray
        }
    }
    
    private var playerScoreColor: Color {
        let matchup = playerEntry.matchup
        
        if matchup.isChoppedLeague {
            // For Chopped leagues, use elimination status
            guard let ranking = matchup.myTeamRanking else { return .gpGreen }
            
            switch ranking.eliminationStatus {
            case .champion, .safe:
                return .gpGreen
            case .warning:
                return .gpYellow
            case .danger:
                return .orange
            case .critical, .eliminated:
                return .gpRedPink
            }
        } else {
            // For regular fantasy matchups, use the same logic as MatchupsHub
            guard let myTeam = matchup.myTeam,
                  let opponentTeam = matchup.opponentTeam else {
                return .gpGreen
            }
            
            let myScore = myTeam.currentScore ?? 0
            let opponentScore = opponentTeam.currentScore ?? 0
            let isWinning = myScore > opponentScore
            
            return isWinning ? .gpGreen : .gpRedPink
        }
    }
    
    private var formattedPlayerName: String {
        let shortName = playerEntry.player.shortName
        
        // Check if it's in "First Last" format and first name is single letter
        let components = shortName.split(separator: " ")
        if components.count >= 2 {
            let firstName = String(components[0])
            let lastName = components[1...]
            
            // If first name is single character, add period
            if firstName.count == 1 {
                return firstName + ". " + lastName.joined(separator: " ")
            }
        }
        
        return shortName
    }
}