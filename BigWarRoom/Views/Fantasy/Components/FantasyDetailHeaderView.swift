//
//  FantasyDetailHeaderView.swift
//  BigWarRoom
//
//  Header component for fantasy matchup detail view with sorting controls
//  FIXED: No clipping + visible nyyDark gradient
//

import SwiftUI

/// Header view for fantasy matchup details with team comparison and sorting controls
struct FantasyDetailHeaderView: View {
    let leagueName: String
    let matchup: FantasyMatchup
    let awayTeamIsWinning: Bool
    let homeTeamIsWinning: Bool
    let fantasyViewModel: FantasyViewModel?
    
    // Sorting parameters
    let sortingMethod: MatchupSortingMethod
    let sortHighToLow: Bool
    let onSortingMethodChanged: (MatchupSortingMethod) -> Void
    let onSortDirectionChanged: () -> Void
    
    /// Dynamic sort direction text based on current method and direction
    private var sortDirectionText: String {
        switch sortingMethod {
        case .score:
            return sortHighToLow ? "↓" : "↑"
        case .name, .position, .team: // UPDATED: Added .team case
            return sortHighToLow ? "Z-A" : "A-Z"
        }
    }
    
    var body: some View {
        // NO FRAME CONSTRAINTS - Let content determine size naturally
        VStack(spacing: 12) { // REDUCED spacing from 18 to 12
            // Team comparison row
            teamComparisonRow
            
            // Sorting controls at bottom - CLOSER TO SCORES
            scoresAndSortingRow
        }
        .padding(.vertical, 20) // Internal padding
        .padding(.horizontal, 20) // Internal padding
	   // stats gradient background
        .background(
            ZStack {
                // MAIN GRADIENT BACKGROUND - More opaque to ensure visibility
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.nyyDark.opacity(0.9), // STRONGER opacity
                        Color.black.opacity(0.7),
                        Color.nyyDark.opacity(0.8) // STRONGER opacity
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // SUBTLE OVERLAY PATTERN
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.nyyDark.opacity(0.1) // Add more nyyDark tint
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            // VISIBLE BORDER
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.nyyDark.opacity(0.8), 
                            Color.white.opacity(0.2),
                            Color.nyyDark.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: Color.nyyDark.opacity(0.4), // Stronger shadow
            radius: 8, 
            x: 0, 
            y: 4
        )
    }
    
    // MARK: - View Components
    
    private var teamComparisonRow: some View {
        HStack(spacing: 24) { // Good spacing between teams
            // Home team (left side)
            VStack(spacing: 4) { // REDUCED spacing from 6 to 4 to accommodate "Yet to play"
                // Avatar with border
                ZStack {
                    if let url = matchup.homeTeam.avatarURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48) // Good size
                                .clipShape(Circle())
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 48, height: 48)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .foregroundColor(.gray)
                    }
                    
                    if homeTeamIsWinning {
                        Circle()
                            .strokeBorder(Color.gpGreen, lineWidth: 2.5)
                            .frame(width: 52, height: 52)
                    }
                }
                
                // Manager name
                Text(matchup.homeTeam.ownerName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Record
                Text(fantasyViewModel?.getManagerRecord(managerID: matchup.homeTeam.id) ?? "0-0")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                // SCORE and YET TO PLAY stack - no extra spacing
                VStack(spacing: 1) {
                    // Team score
                    Text(String(format: "%.2f", matchup.homeTeam.currentScore ?? 0.0))
                        .font(.system(size: 22, weight: .bold)) // Large, visible score
                        .foregroundColor(homeTeamIsWinning ? .gpGreen : .red)
                    
                    // Yet to play count
                    Text("Yet to play: \(homeTeamYetToPlay)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2) // SMALL padding to bring score closer
            }
            .frame(maxWidth: .infinity)
            
            // Center VS section
            VStack(spacing: 4) {
                Text("VS")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Week \(fantasyViewModel?.selectedWeek ?? matchup.week)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                
                if let scoreDiff = fantasyViewModel?.scoreDifferenceText(matchup: matchup), !scoreDiff.isEmpty {
                    Text(scoreDiff)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gpGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.4))
                        )
                }
            }
            .frame(width: 70)
            
            // Away team (right side)
            VStack(spacing: 4) { // REDUCED spacing from 6 to 4 to accommodate "Yet to play"
                // Avatar with border
                ZStack {
                    if let url = matchup.awayTeam.avatarURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48) // Good size
                                .clipShape(Circle())
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 48, height: 48)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .foregroundColor(.gray)
                    }
                    
                    if awayTeamIsWinning {
                        Circle()
                            .strokeBorder(Color.gpGreen, lineWidth: 2.5)
                            .frame(width: 52, height: 52)
                    }
                }
                
                // Manager name
                Text(matchup.awayTeam.ownerName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Record
                Text(fantasyViewModel?.getManagerRecord(managerID: matchup.awayTeam.id) ?? "0-0")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                // SCORE and YET TO PLAY stack - no extra spacing
                VStack(spacing: 1) {
                    // Team score
                    Text(String(format: "%.2f", matchup.awayTeam.currentScore ?? 0.0))
                        .font(.system(size: 22, weight: .bold)) // Large, visible score
                        .foregroundColor(awayTeamIsWinning ? .gpGreen : .red)
                    
                    // Yet to play count
                    Text("Yet to play: \(awayTeamYetToPlay)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2) // SMALL padding to bring score closer
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var scoresAndSortingRow: some View {
        HStack {
            Spacer()
            
            // Sorting controls CENTERED
            HStack(spacing: 10) { // Good spacing between controls
                // Sort method picker - SIZE 14
                Menu {
                    ForEach(MatchupSortingMethod.allCases) { method in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onSortingMethodChanged(method)
                            }
                        }) {
                            HStack {
                                Text(method.displayName)
                                if sortingMethod == method {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(sortingMethod.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12) // Slightly reduced padding
                        .padding(.vertical, 6) // Slightly reduced padding
                        .background(Color.blue.opacity(0.2)) // More visible background
                        .clipShape(RoundedRectangle(cornerRadius: 8)) 
                }
                
                // Sort direction toggle - SIZE 14
                Button(action: {
                    onSortDirectionChanged()
                }) {
                    Text(sortDirectionText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12) // Slightly reduced padding
                        .padding(.vertical, 6) // Slightly reduced padding
                        .background(Color.orange.opacity(0.2)) // More visible background
                        .clipShape(RoundedRectangle(cornerRadius: 8)) 
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties (Data Only)
    
    /// Calculate number of players yet to play for home team
    private var homeTeamYetToPlay: Int {
        calculateYetToPlay(for: matchup.homeTeam)
    }
    
    /// Calculate number of players yet to play for away team
    private var awayTeamYetToPlay: Int {
        calculateYetToPlay(for: matchup.awayTeam)
    }
    
    /// Calculate number of players yet to play for a given team
    /// Players "yet to play" are starters with 0 points who haven't played yet
    private func calculateYetToPlay(for team: FantasyTeam) -> Int {
        return team.roster.filter { player in
            // Only count starters
            guard player.isStarter else { return false }
            
            // Only count players with 0 points
            guard (player.currentPoints ?? 0.0) == 0.0 else { return false }
            
            // Check if player has actually played by looking at game status
            // If gameStatus is nil, assume they haven't played yet
            if let gameStatus = player.gameStatus {
                // If they have a game status and it's not "Final", they're yet to play
                let gameStatusString = gameStatus.status.lowercased()
                return !gameStatusString.contains("final") && !gameStatusString.contains("post")
            }
            
            // If no game status available, assume they're yet to play if they have 0 points
            return true
        }.count
    }
}