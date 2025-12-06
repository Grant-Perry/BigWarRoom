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
    @Binding var showYetToPlayOnly: Bool
    @FocusState private var isSearchFocused: Bool
    
    // 👁️ NEW: Watched Players Sheet state
    @State private var showingWatchedPlayers = false
    // 🔥 PHASE 3 DI: Remove .shared assignment, will be passed from parent
    @State private var watchService: PlayerWatchService
    
    // 🔥 PHASE 3 DI: Accept GameStatusService for "yet to play" calculations  
    let gameStatusService: GameStatusService?
    
    // 🔥 PHASE 3 DI: Add initializer with watchService
    init(
        leagueName: String,
        matchup: FantasyMatchup,
        awayTeamIsWinning: Bool,
        homeTeamIsWinning: Bool,
        fantasyViewModel: FantasyViewModel?,
        sortingMethod: MatchupSortingMethod,
        sortHighToLow: Bool,
        onSortingMethodChanged: @escaping (MatchupSortingMethod) -> Void,
        onSortDirectionChanged: @escaping () -> Void,
        selectedPosition: Binding<FantasyPosition>,
        showActiveOnly: Binding<Bool>,
        showYetToPlayOnly: Binding<Bool>,
        watchService: PlayerWatchService,
        gameStatusService: GameStatusService? = nil
    ) {
        self.leagueName = leagueName
        self.matchup = matchup
        self.awayTeamIsWinning = awayTeamIsWinning
        self.homeTeamIsWinning = homeTeamIsWinning
        self.fantasyViewModel = fantasyViewModel
        self.sortingMethod = sortingMethod
        self.sortHighToLow = sortHighToLow
        self.onSortingMethodChanged = onSortingMethodChanged
        self.onSortDirectionChanged = onSortDirectionChanged
        self._selectedPosition = selectedPosition
        self._showActiveOnly = showActiveOnly
        self._showYetToPlayOnly = showYetToPlayOnly
        self._watchService = State(initialValue: watchService)
        self.gameStatusService = gameStatusService
    }
    
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
        VStack(spacing: 0) {
            // Team comparison row - COMPACT VERSION
            teamComparisonRow
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            
            // Enhanced controls section with distinct background
            enhancedControlsSection
                .background(
                    // Darker, distinct background for filter row
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    // Subtle border to separate from header
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
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
        HStack(spacing: 20) {
            // Home team (left side) - COMPACT
            VStack(spacing: 3) {
                // Manager name FIRST
                Text(matchup.homeTeam.ownerName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Avatar and Record on same line
                HStack(spacing: 6) {
                    // Smaller Avatar with border
                    ZStack {
                        if let url = matchup.homeTeam.avatarURL {
                            AsyncTeamAvatarView(
                                url: url,
                                size: 32,
                                fallbackInitials: getInitials(from: matchup.homeTeam.ownerName)
                            )
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(getInitials(from: matchup.homeTeam.ownerName))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        if homeTeamIsWinning {
                            Circle()
                                .strokeBorder(Color.gpGreen, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        }
                    }
                    
                    // Record (lose "Record:" label)
                    let homeRecordText: String = {
                        let managerID = matchup.homeTeam.id
                        
                        if let record = matchup.homeTeam.record {
                            return record.displayString
                        }
                        
                        if let teamId = Int(managerID),
                           let record = fantasyViewModel?.espnTeamRecords[teamId] {
                            return record.displayString
                        }
                        
                        if let record = fantasyViewModel?.getManagerRecord(managerID: managerID), !record.isEmpty {
                            return record
                        }
                        
                        return "N/A"
                    }()
                    Text(homeRecordText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // SCORE
                Text(String(format: "%.2f", matchup.homeTeam.currentScore ?? 0.0))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(homeTeamIsWinning ? .gpGreen : .red)
                
                // Yet to play - larger number
                HStack(spacing: 3) {
                    Text("Yet to play:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(homeTeamYetToPlay)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(homeTeamIsWinning ? .gpGreen : .red)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Center VS section - COMPACT
            VStack(spacing: 2) {
                Text("VS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Week \(fantasyViewModel?.selectedWeek ?? matchup.week)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                if let scoreDiff = fantasyViewModel?.scoreDifferenceText(matchup: matchup), !scoreDiff.isEmpty {
                    Text(scoreDiff)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gpGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.4))
                        )
                }
            }
            .frame(width: 60)
            
            // Away team (right side) - COMPACT
            VStack(spacing: 3) {
                // Manager name FIRST
                Text(matchup.awayTeam.ownerName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Avatar and Record on same line
                HStack(spacing: 6) {
                    // Record (lose "Record:" label)
                    let awayRecordText: String = {
                        let managerID = matchup.awayTeam.id
                        
                        if let record = matchup.awayTeam.record {
                            return record.displayString
                        }
                        
                        if let teamId = Int(managerID),
                           let record = fantasyViewModel?.espnTeamRecords[teamId] {
                            return record.displayString
                        }
                        
                        if let record = fantasyViewModel?.getManagerRecord(managerID: managerID), !record.isEmpty {
                            return record
                        }
                        
                        return "N/A"
                    }()
                    Text(awayRecordText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                    
                    // Smaller Avatar with border
                    ZStack {
                        if let url = matchup.awayTeam.avatarURL {
                            AsyncTeamAvatarView(
                                url: url,
                                size: 32,
                                fallbackInitials: getInitials(from: matchup.awayTeam.ownerName)
                            )
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.6), Color.red.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(getInitials(from: matchup.awayTeam.ownerName))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        if awayTeamIsWinning {
                            Circle()
                                .strokeBorder(Color.gpGreen, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                
                // SCORE
                Text(String(format: "%.2f", matchup.awayTeam.currentScore ?? 0.0))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(awayTeamIsWinning ? .gpGreen : .red)
                
                // Yet to play - larger number
                HStack(spacing: 3) {
                    Text("Yet to play:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(awayTeamYetToPlay)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(awayTeamIsWinning ? .gpGreen : .red)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Enhanced Controls Section
    
    private var enhancedControlsSection: some View {
        HStack(spacing: 12) {
            // Sort Method with conditional arrow
            HStack(spacing: 6) {
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
                    VStack(spacing: 1) {
                        Text(sortingMethod.displayName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        
                        Text("Sort By")
                            .font(.system(size: 9, weight: .medium))
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
                            .font(.system(size: 12, weight: .bold))
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
                VStack(spacing: 1) {
                    Text(selectedPosition.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(selectedPosition == .all ? .gpBlue : .purple)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Position")
                        .font(.system(size: 9, weight: .medium))
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
                VStack(spacing: 1) {
                    Text(showActiveOnly ? "Yes" : "No")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(showActiveOnly ? .gpGreen : .gpRedPink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Active Only")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Yet to Play toggle
            Button(action: {
                showYetToPlayOnly.toggle()
            }) {
                VStack(spacing: 1) {
                    Text(showYetToPlayOnly ? "Only" : "All")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(showYetToPlayOnly ? .gpYellow : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Yet to Play")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: 60)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: {
                showingWatchedPlayers = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gpYellow)
                    
                    // Red circle badge if there are watched players
                    if watchService.watchedPlayers.count > 0 {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 14, height: 14)
                            
                            Text("\(watchService.watchedPlayers.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
            
            // 🔥 PHASE 3 DI: Use injected GameStatusService if available
            if let gameStatusService = gameStatusService {
                return gameStatusService.isPlayerYetToPlay(
                    playerTeam: player.team,
                    currentPoints: player.currentPoints
                )
            }
            
            // Fallback logic if no GameStatusService provided
            let hasZeroPoints = (player.currentPoints ?? 0.0) == 0.0
            return hasZeroPoints
        }.count
    }
    
    // MARK: - Helper Methods
    
    /// Get initials from manager name for avatar fallback
    private func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }
}