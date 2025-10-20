//
//  PlayerRosteredSectionView.swift
//  BigWarRoom
//
//  Shows all leagues where this player is rostered for the user
//

import SwiftUI

/// Shows all leagues where this player is rostered for the user
struct PlayerRosteredSectionView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    let matchups: [UnifiedMatchup] // 🔥 PASS DATA INSTEAD OF OBSERVING
    
    // 🔥 REMOVE: No more observing the shared view model
    // @StateObject private var matchupsHubViewModel = MatchupsHubViewModel.shared
    @State private var isExpanded: Bool = true // Changed to true for initial expanded state
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.fill.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.gpBlue)
                        
                        Text("Rostered")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(rosteredForMe.count + rosteredAgainstMe.count) leagues")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Collapsible Content
            if isExpanded {
                if rosteredForMe.isEmpty && rosteredAgainstMe.isEmpty {
                    emptyStateView
                } else {
                    rosteredContent
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(overlayBorder)
        .shadow(color: (team?.primaryColor ?? Color.gpBlue).opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Content Views
    
    private var rosteredContent: some View {
        VStack(spacing: 8) {
            // "FOR ME" Section
            if !rosteredForMe.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.caption)
                            .foregroundColor(.gpGreen)
                        
                        Text("FOR")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gpGreen)
                    }
                    
                    LazyVStack(spacing: 6) {
                        ForEach(rosteredForMe, id: \.id) { matchup in
                            RosteredLeagueRow(matchup: matchup)
                        }
                    }
                }
            }
            
            // "AGAINST ME" Section
            if !rosteredAgainstMe.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.caption)
                            .foregroundColor(.gpRedPink)
                        
                        Text("AGAINST")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gpRedPink)
                    }
                    
                    LazyVStack(spacing: 6) {
                        ForEach(rosteredAgainstMe, id: \.id) { matchup in
                            RosteredLeagueRow(matchup: matchup)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Not rostered in any leagues")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Computed Properties
    
    /// Find all matchups where this player is on my team
    private var rosteredMatchups: [UnifiedMatchup] {
        return matchups.filter { matchup in
            if matchup.isChoppedLeague {
                // Check if player is on my chopped team
                return matchup.myTeam?.roster.contains { rosterPlayer in
                    // More robust matching - check multiple identifiers
                    let nameMatch = rosterPlayer.fullName.lowercased() == self.player.fullName.lowercased()
                    let sleeperIDMatch = rosterPlayer.sleeperID == self.player.playerID
                    return nameMatch || sleeperIDMatch
                } ?? false
            } else {
                // Check if player is on my fantasy team
                return matchup.myTeam?.roster.contains { rosterPlayer in
                    // More robust matching - check multiple identifiers  
                    let nameMatch = rosterPlayer.fullName.lowercased() == self.player.fullName.lowercased()
                    let sleeperIDMatch = rosterPlayer.sleeperID == self.player.playerID
                    return nameMatch || sleeperIDMatch
                } ?? false
            }
        }
    }
    
    // Find all matchups where this player is on my team
    private var rosteredForMe: [UnifiedMatchup] {
        return matchups.filter { matchup in
            return matchup.myTeam?.roster.contains { rosterPlayer in
                // Try multiple matching strategies for robustness
                
                // Strategy 1: SleeperID matching (for Sleeper leagues)
                if let rosterSleeperID = rosterPlayer.sleeperID {
                    let playerIDString = String(self.player.playerID)
                    if rosterSleeperID == playerIDString {
                        return true
                    }
                }
                
                // Strategy 2: Name matching (fallback for ESPN leagues or missing IDs)
                let normalizedPlayerName = self.player.fullName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedRosterName = rosterPlayer.fullName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if normalizedPlayerName == normalizedRosterName {
                    return true
                }
                
                // Strategy 3: Handle name variations (Jr., Sr., etc.)
                let playerBaseName = normalizedPlayerName.replacingOccurrences(of: " jr.", with: "").replacingOccurrences(of: " sr.", with: "").replacingOccurrences(of: " iii", with: "").replacingOccurrences(of: " ii", with: "")
                let rosterBaseName = normalizedRosterName.replacingOccurrences(of: " jr.", with: "").replacingOccurrences(of: " sr.", with: "").replacingOccurrences(of: " iii", with: "").replacingOccurrences(of: " ii", with: "")
                
                return playerBaseName == rosterBaseName
            } ?? false
        }
    }
    
    // Find all matchups where this player is on my opponent's team
    private var rosteredAgainstMe: [UnifiedMatchup] {
        return matchups.filter { matchup in
            // Chopped leagues don't have direct opponents, so this doesn't apply
            guard !matchup.isChoppedLeague else { return false }
            
            return matchup.opponentTeam?.roster.contains { rosterPlayer in
                // Try multiple matching strategies for robustness
                
                // Strategy 1: SleeperID matching (for Sleeper leagues)
                if let rosterSleeperID = rosterPlayer.sleeperID {
                    let playerIDString = String(self.player.playerID)
                    if rosterSleeperID == playerIDString {
                        return true
                    }
                }
                
                // Strategy 2: Name matching (fallback for ESPN leagues or missing IDs)
                let normalizedPlayerName = self.player.fullName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedRosterName = rosterPlayer.fullName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if normalizedPlayerName == normalizedRosterName {
                    return true
                }
                
                // Strategy 3: Handle name variations (Jr., Sr., etc.)
                let playerBaseName = normalizedPlayerName.replacingOccurrences(of: " jr.", with: "").replacingOccurrences(of: " sr.", with: "").replacingOccurrences(of: " iii", with: "").replacingOccurrences(of: " ii", with: "")
                let rosterBaseName = normalizedRosterName.replacingOccurrences(of: " jr.", with: "").replacingOccurrences(of: " sr.", with: "").replacingOccurrences(of: " iii", with: "").replacingOccurrences(of: " ii", with: "")
                
                return playerBaseName == rosterBaseName
            } ?? false
        }
    }
    
    // MARK: - Background and Styling (Same as Live Game Stats)
    
    private var backgroundView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    team?.primaryColor.opacity(0.6) ?? Color.gpBlue.opacity(0.6),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle pattern overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1),
                    Color.clear,
                    Color.white.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var overlayBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                LinearGradient(
                    colors: [Color.gpBlue, team?.accentColor ?? Color.gpGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}

/// Individual league row showing where player is rostered
private struct RosteredLeagueRow: View {
    let matchup: UnifiedMatchup
    
    @Environment(\.dismiss) private var dismiss
    // 🏈 NAVIGATION FREEDOM: Remove sheet state - using NavigationLink instead
    // @State private var showingMatchupDetail = false
    
    var body: some View {
        // 🏈 NAVIGATION FREEDOM: Use NavigationLink instead of Button + sheet
        // BEFORE: Button with sheet presentation
        // AFTER: NavigationLink for proper navigation with tab bar visibility
        NavigationLink(destination: MatchupDetailSheetsView(matchup: matchup)) {
            HStack(spacing: 8) {
                // Platform logo (ESPN or Sleeper)
                platformLogo
                    .frame(width: 20, height: 20)
                
                // League name with CHOPPED suffix if applicable
                HStack(spacing: 4) {
                    Text(matchup.league.league.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if matchup.isChoppedLeague {
                        Text("-")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.gpYellow)
                        
                        Text("CHOPPED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.gpYellow)
                    }
                }
                
                Spacer()
                
                // Team record or status
                if matchup.isChoppedLeague {
                    if let ranking = matchup.myTeamRanking {
                        Text("#\(ranking.rank)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(eliminationStatusColor(ranking.eliminationStatus))
                    }
                } else {
                    if let myTeam = matchup.myTeam, let record = myTeam.record {
                        Text("\(record.wins)-\(record.losses)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
        // 🏈 NAVIGATION FREEDOM: Remove sheet - using NavigationLink instead
        // .sheet(isPresented: $showingMatchupDetail) { MatchupDetailSheetsView(matchup: matchup) }
    }
    
    // MARK: - Computed Properties
    
    private var platformLogo: some View {
        Group {
            switch matchup.league.source {
            case .espn:
                Image("espnLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .sleeper:
                Image("sleeperLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
    
    private func eliminationStatusColor(_ status: EliminationStatus) -> Color {
        switch status {
        case .champion, .safe:
            return .gpGreen
        case .warning:
            return .gpYellow
        case .danger:
            return .orange
        case .critical, .eliminated:
            return .gpRedPink
        }
    }
}

