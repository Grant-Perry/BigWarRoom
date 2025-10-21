//
//  FantasyDetailHeaderView.swift
//  BigWarRoom
//
//  Header component for fantasy matchup detail view with enhanced sorting controls
//  ENHANCED: Full All Live Players style controls with search, position filter, active filter
//  CONNECTED: Filter states now properly bound to parent view
//

import SwiftUI

/// Header view for fantasy matchup details with team comparison and comprehensive sorting controls
struct FantasyDetailHeaderView: View {
    let leagueName: String
    let matchup: FantasyMatchup
    let awayTeamIsWinning: Bool
    let homeTeamIsWinning: Bool
    let fantasyViewModel: FantasyViewModel?
    
    // Enhanced sorting and filtering parameters
    let sortingMethod: MatchupSortingMethod
    let sortHighToLow: Bool
    let onSortingMethodChanged: (MatchupSortingMethod) -> Void
    let onSortDirectionChanged: () -> Void
    
    // NEW: Bound filter states (connected to parent)
    @Binding var selectedPosition: FantasyPosition
    @Binding var showActiveOnly: Bool
    @FocusState private var isSearchFocused: Bool
    
    // 👁️ NEW: Watched Players Sheet state
    @State private var showingWatchedPlayers = false
    @ObservedObject private var watchService = PlayerWatchService.shared
    
    /// Dynamic sort direction text based on current method and direction
    private var sortDirectionText: String {
        switch sortingMethod {
        case .score:
            return sortHighToLow ? "↓" : "↑"
        case .name, .position, .team:
            return sortHighToLow ? "Z-A" : "A-Z"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Team comparison row
            teamComparisonRow
            
            // Enhanced controls section
            enhancedControlsSection
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                // Main gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.nyyDark.opacity(0.9),
                        Color.black.opacity(0.7),
                        Color.nyyDark.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle overlay pattern
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.nyyDark.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
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
            color: Color.nyyDark.opacity(0.4),
            radius: 8, 
            x: 0, 
            y: 4
        )
        // 👁️ NEW: Watched Players Sheet
        .sheet(isPresented: $showingWatchedPlayers) {
            WatchedPlayersSheet(watchService: watchService)
        }
    }
    
    // MARK: - View Components
    
    private var teamComparisonRow: some View {
        HStack(spacing: 24) {
            // Home team (left side)
            VStack(spacing: 4) {
                // Avatar with border
                ZStack {
                    if let url = matchup.homeTeam.avatarURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
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
                
                // Record - only show if not empty
                let homeRecord = fantasyViewModel?.getManagerRecord(managerID: matchup.homeTeam.id) ?? ""
                if !homeRecord.isEmpty {
                    Text(homeRecord)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // SCORE and YET TO PLAY stack
                VStack(spacing: 1) {
                    // Team score
                    Text(String(format: "%.2f", matchup.homeTeam.currentScore ?? 0.0))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(homeTeamIsWinning ? .gpGreen : .red)
                    
                    // Yet to play count
                    Text("Yet to play: \(homeTeamYetToPlay)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
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
            VStack(spacing: 4) {
                // Avatar with border
                ZStack {
                    if let url = matchup.awayTeam.avatarURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
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
                
                // Record - only show if not empty
                let awayRecord = fantasyViewModel?.getManagerRecord(managerID: matchup.awayTeam.id) ?? ""
                if !awayRecord.isEmpty {
                    Text(awayRecord)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // SCORE and YET TO PLAY stack
                VStack(spacing: 1) {
                    // Team score
                    Text(String(format: "%.2f", matchup.awayTeam.currentScore ?? 0.0))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(awayTeamIsWinning ? .gpGreen : .red)
                    
                    // Yet to play count
                    Text("Yet to play: \(awayTeamYetToPlay)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Enhanced Controls Section
    
    private var enhancedControlsSection: some View {
        HStack {
            // 👁️ NEW: Watch Icon with Badge (left side)
            Button(action: {
                showingWatchedPlayers = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gpYellow)
                    
                    // Red circle badge if there are watched players
                    if watchService.watchedPlayers.count > 0 {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 16, height: 16)
                            
                            Text("\(watchService.watchedPlayers.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Sort Method with conditional arrow
            HStack(spacing: 8) {
                // Sort Method Menu
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
                    VStack(spacing: 2) {
                        Text(sortingMethod.displayName.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        
                        Text(sortingMethod == .score ? (sortHighToLow ? "Highest" : "Lowest") : "Sort By")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                // Sort Direction Arrow (only show for Score)
                if sortingMethod == .score {
                    Button(action: {
                        onSortDirectionChanged()
                    }) {
                        Image(systemName: sortHighToLow ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gpGreen)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
            
            // Position filter with picker
            Menu {
                ForEach(FantasyPosition.allCases) { position in
                    Button(action: {
                        selectedPosition = position
                    }) {
                        HStack {
                            Text(position.displayName)
                            if selectedPosition == position {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Text(selectedPosition.displayName.uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(selectedPosition == .all ? .gpBlue : .purple)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Position")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .menuStyle(BorderlessButtonMenuStyle())
            
            Spacer()
            
            // Active Only toggle
            Button(action: {
                showActiveOnly.toggle()
            }) {
                VStack(spacing: 2) {
                    Text(showActiveOnly ? "Yes" : "No")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(showActiveOnly ? .gpGreen : .gpRedPink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Active Only")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
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
            
            // Use GameStatusService for authoritative "yet to play" calculation
            return GameStatusService.shared.isPlayerYetToPlay(
                playerTeam: player.team,
                currentPoints: player.currentPoints
            )
        }.count
    }
}