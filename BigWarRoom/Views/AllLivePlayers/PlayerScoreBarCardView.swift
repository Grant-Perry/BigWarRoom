//
//  PlayerScoreBarCardView.swift
//  BigWarRoom
//
//  Seamless player card with animated score bar integration - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let animateIn: Bool
    let onTap: (() -> Void)? // 🔥 DEATH TO SHEETS: Made optional for NavigationLink usage
    
    // 🔥 PHASE 3: Use @Bindable for @Observable ViewModels
    @Bindable var viewModel: AllLivePlayersViewModel
    
    // 🔥 PHASE 3 DI: Add watchService as parameter
    let watchService: PlayerWatchService
    
    @State private var scoreBarWidth: Double = 0.0
    @State private var cardOffset: Double = 50.0
    @State private var cardOpacity: Double = 0.0
    
    private let maxScoreBarWidth: Double = 120.0 // Maximum width in points
    private let cardHeight: Double = 110.0 // Increased card height to accommodate stats at bottom (was 95.0)
    private let scoreBarHeight: Double = 20.0 // Shorter score bar (was 23.3)
    private let scoreBarOpacity: Double = 0.35 // Score bar transparency
    
    var body: some View {
        // 🔥 DEATH TO SHEETS: Conditionally wrap in Button only if onTap provided
        Group {
            if let onTap = onTap {
                // Use Button for tap handling
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // No Button wrapper - for use with NavigationLink
                cardContent
            }
        }
        .id(playerEntry.id) // Force view refresh
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
                // Force a small delay to ensure view is fully laid out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scoreBarWidth = playerEntry.scoreBarWidth
                }
            }
        }
        .onChange(of: playerEntry.scoreBarWidth) { _, newWidth in
            // Smooth animation when scores update (left to right growth)
            withAnimation(.easeInOut(duration: 0.6)) {
                scoreBarWidth = newWidth
            }
        }
    }
    
    // 🔥 DEATH TO SHEETS: Extract card content to reusable computed property
    private var cardContent: some View {
        PlayerScoreBarCardContentView(
            playerEntry: playerEntry,
            scoreBarWidth: scoreBarWidth,
            cardHeight: cardHeight,
            formattedPlayerName: formattedPlayerName,
            playerScoreColor: playerScoreColor,
            viewModel: viewModel,
            watchService: watchService,
            playerDirectory: viewModel.playerDirectory // 🔥 PHASE 3 DI: Pass playerDirectory from viewModel
        )
    }
    
    // MARK: - Computed Properties (DATA ONLY - No Views)
    
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
        // 🔥 FIXED: Use full name instead of short name initials
        let fullName = playerEntry.player.fullName
        
        // Check if it's in "First Last" format and first name is single letter in shortName
        let shortName = playerEntry.player.shortName
        let shortComponents = shortName.split(separator: " ")
        
        if shortComponents.count >= 2 {
            let firstName = String(shortComponents[0])
            
            // If short name uses single character, but we have full name, use full name
            if firstName.count == 1 && !fullName.isEmpty {
                return fullName
            }
            
            // If first name is single character in short name, add period to short name
            if firstName.count == 1 {
                let lastName = shortComponents[1...]
                return firstName + ". " + lastName.joined(separator: " ")
            }
        }
        
        // Default to full name if available, otherwise short name
        return !fullName.isEmpty ? fullName : shortName
    }
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
    
    private var playerCardGradColor: Color {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.primaryColor
        }
        return .nyyDark // Fallback to original color if no team found
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
    
    /// Original score bar colors (back to .gpGreen and blue)
    private var originalScoreBarColor: Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen.opacity(scoreBarOpacity) }        // Elite - Green
        else if percentage >= 0.5 { return .blue.opacity(scoreBarOpacity) }       // Good - Blue  
        else if percentage >= 0.25 { return .orange.opacity(scoreBarOpacity) }    // Okay - Orange
        else { return .red.opacity(scoreBarOpacity) }                             // Poor - Red
    }
    
    private var scoreBarColor: Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen.opacity(0.4) }
        else if percentage >= 0.5 { return .blue.opacity(0.3) }
        else if percentage >= 0.25 { return .orange.opacity(0.3) }
        else { return .red.opacity(0.2) }
    }

    /// Alternative image URL for retry logic
    private var alternativeImageURL: URL? {
        // Try ESPN headshot as fallback
        if let espnURL = playerEntry.player.espnHeadshotURL {
            return espnURL
        }
        
        // For defense/special teams, try a different approach
        if playerEntry.position == "DEF" || playerEntry.position == "DST" {
            if let team = playerEntry.player.team {
                // Try ESPN team logo as player image for defenses
                return URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")
            }
        }
        
        return nil
    }
    
}