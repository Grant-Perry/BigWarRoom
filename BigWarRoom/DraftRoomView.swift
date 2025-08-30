//
//  DraftRoomView.swift
//  DraftWarRoom
//
//  Main Draft Room UI
//
// MARK: -> View

import SwiftUI

struct DraftRoomView: View {
    @ObservedObject var viewModel: DraftRoomViewModel

    // MARK: -> State variables
    @State private var customSleeperInput: String = AppConstants.GpSleeperID
    @State private var showAllLeagues = false
    @State private var manualDraftID: String = ""
    @State private var isConnectingToDraft = false
    @State private var selectedPlayerForStats: Player?
    @State private var showingPlayerStats = false
    @State private var showConnectionSection = false // Default closed

    // MARK: -> Enhanced Suggestions
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top \(viewModel.suggestions.count) Suggestions")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isLiveMode {
                    Image(systemName: "wifi")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            // Position Filter
            positionFilterSection
            
            if viewModel.suggestions.isEmpty {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading player suggestions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Choose display method based on sort method
                if viewModel.selectedSortMethod == .all {
                    // LazyVStack for "All" - can handle thousands of players
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.suggestions) { suggestion in
                                enhancedSuggestionCardForAll(suggestion)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 600)
                    .background(Color(.systemGray6).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // List with swipe actions for Wizard and Rankings
                    List {
                        ForEach(viewModel.suggestions) { suggestion in
                            enhancedSuggestionCard(suggestion)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        }
                    }
                    .listStyle(.plain)
                    .frame(height: 600) // Reduced since we removed the picks section
                    .background(Color(.systemGray6).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: -> Position Filter Section
    
    private var positionFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sort Method Toggle
            sortMethodToggle
            
            // Position Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Filter by Position")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PositionFilter.allCases) { filter in
                            Button {
                                viewModel.updatePositionFilter(filter)
                            } label: {
                                Text(filter.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.selectedPositionFilter == filter 
                                        ? Color.blue 
                                        : Color(.systemGray5)
                                    )
                                    .foregroundColor(
                                        viewModel.selectedPositionFilter == filter 
                                        ? .white 
                                        : .primary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: -> Sort Method Toggle
    
    private var sortMethodToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ranking Method")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(SortMethod.allCases) { method in
                    Button {
                        viewModel.updateSortMethod(method)
                    } label: {
                        Text(method.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedSortMethod == method 
                                ? Color.green 
                                : Color(.systemGray4)
                            )
                            .foregroundColor(
                                viewModel.selectedSortMethod == method 
                                ? .white 
                                : .primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                Spacer()
                
                // Show current method description
                Text(viewModel.selectedSortMethod == .wizard ? "AI Strategy" : viewModel.selectedSortMethod == .rankings ? "Pure Rankings" : "All Players")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func enhancedSuggestionCard(_ suggestion: Suggestion) -> some View {
        HStack(spacing: 12) {
            // Player headshot - improved lookup logic
            playerImageForSuggestion(suggestion.player)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Custom player name and position display
                    playerNameAndPositionView(for: suggestion)
                    
                    // Tier badge (T1 = Elite, T2 = Very Good, etc.)
                    tierBadge(suggestion.player.tier)
                    
                    // Team logo (much larger size)
                    TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                        .frame(width: 42, height: 42)
                    
                    Spacer()
                }
                
                // Player details: fantasy rank, jersey, years, injury status all on one line
                playerDetailsRow(for: suggestion.player)
            }
        }
        .padding(12)
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            // Tap to show player stats
            showPlayerStats(for: suggestion.player)
        }
        // Only add swipe actions for non-"All" modes (List view)
        .conditionalSwipeActions(condition: viewModel.selectedSortMethod != .all) {
            // Swipe left (from right edge) to Add to Feed
            Button("Add") {
                addPlayerToFeed(suggestion)
            }
            .tint(.blue)
        } leading: {
            // Swipe right (from left edge) to Lock as My Pick
            Button("Lock") {
                lockPlayerAsPick(suggestion)
            }
            .tint(.green)
        }
    }
    
    // MARK: -> Enhanced Suggestion Card for "All" view (LazyVStack - no swipe actions)
    
    private func enhancedSuggestionCardForAll(_ suggestion: Suggestion) -> some View {
        HStack(spacing: 16) {  
            // Player headshot with position number badge overlay
            ZStack(alignment: .topTrailing) {
                // Player headshot - improved lookup logic
                playerImageForSuggestion(suggestion.player)
                
                // Sequential position number in blue gradient circle
                if let index = viewModel.suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            // Player info - expanded to fill more space
            VStack(alignment: .leading, spacing: 6) {  
                // Player name and position on TOP row with team logo/tier on trailing edge
                HStack(spacing: 8) {
                    // Custom player name and position display
                    playerNameAndPositionView(for: suggestion)
                    
                    Spacer()
                    
                    // Team logo and tier badge all the way to trailing edge
                    HStack(spacing: 8) {
                        // Tier badge
                        tierBadge(suggestion.player.tier)
                        
                        // Team logo
                        TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                            .frame(width: 42, height: 42)
                    }
                }
                
                // Player details: jersey, years, injury status (second row)
                playerDetailsRowForAll(for: suggestion.player)
            }
        }
        .padding(.horizontal, 16)  
        .padding(.vertical, 14)    
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            // Tap to show player stats
            showPlayerStats(for: suggestion.player)
        }
        // Add gesture recognizers for add/lock actions since no swipe actions in LazyVStack
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press to lock as my pick
            lockPlayerAsPick(suggestion)
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        // Add contextual menu for additional actions
        .contextMenu {
            Button("Lock as My Pick") {
                lockPlayerAsPick(suggestion)
            }
            
            Button("Add to Feed") {
                addPlayerToFeed(suggestion)
            }
        }
    }
    
    // MARK: -> Step 1: Quick Connect Section (Now Collapsible)
    
    private var quickConnectSection: some View {
        VStack(spacing: 12) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showConnectionSection.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connection")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if viewModel.connectionStatus == .connected {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.sleeperDisplayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Connect to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Chevron indicator
                    Image(systemName: showConnectionSection ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Connection options (only show if expanded)
            if showConnectionSection {
                VStack(spacing: 12) {
                    // Action buttons row
                    HStack(spacing: 12) {
                        if viewModel.connectionStatus == .connected {
                            Button("Disconnect") {
                                viewModel.disconnectFromLive()
                            }
                            .font(.callout)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            // Sleeper connection
                            Button {
                                Task {
                                    await viewModel.connectWithUsernameOrID(customSleeperInput)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    AppConstants.sleeperLogo
                                        .frame(width: 16, height: 16) // Smaller logo
                                    Text("Connect Sleeper")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .disabled(customSleeperInput.isEmpty)
                            
                            // ESPN connection
                            Button {
                                Task { await viewModel.connectToESPNOnly() }
                            } label: {
                                HStack(spacing: 6) {
                                    AppConstants.espnLogo
                                        .frame(width: 16, height: 16) // Smaller logo
                                    Text("Connect ESPN")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.primary) // Remove red background
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6)) // Neutral background
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Sleeper ID input (only show if not connected)
                    if viewModel.connectionStatus != .connected {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                AppConstants.sleeperLogo
                                    .frame(width: 18, height: 18) // Smaller logo
                                Text("Sleeper Username/ID")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack(spacing: 8) {
                                TextField("e.g. 'gpick' or user ID", text: $customSleeperInput)
                                    .textFieldStyle(.roundedBorder)
                                    .fontDesign(.monospaced)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                
                                Button("Paste") {
                                    if let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) {
                                        customSleeperInput = clipboardText
                                    }
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Button("Use Default (Gp)") {
                                    customSleeperInput = AppConstants.GpSleeperID
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: -> Step 2: Draft Selection Section
    
    private var draftSelectionSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Select Draft")
                    .font(.headline)
                
                Spacer()
                
                // League count
                if !viewModel.allAvailableDrafts.isEmpty {
                    Text("\(viewModel.allAvailableDrafts.count) leagues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Your leagues (if available)
            if !viewModel.allAvailableDrafts.isEmpty {
                VStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllLeagues.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Your Leagues")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Image(systemName: showAllLeagues ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                    }
                    
                    if showAllLeagues {
                        LazyVStack(spacing: 6) {
                            ForEach(viewModel.allAvailableDrafts.prefix(5)) { leagueWrapper in
                                CompactLeagueCard(
                                    leagueWrapper: leagueWrapper,
                                    isSelected: leagueWrapper.id == viewModel.selectedLeagueWrapper?.id,
                                    onSelect: {
                                        Task { await viewModel.selectDraft(leagueWrapper) }
                                    }
                                )
                            }
                            
                            if viewModel.allAvailableDrafts.count > 5 {
                                Text("+ \(viewModel.allAvailableDrafts.count - 5) more leagues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            
            // Manual draft entry
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Manual Draft ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 8) {
                    TextField("Enter any draft ID", text: $manualDraftID)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.monospaced)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .disabled(isConnectingToDraft)
                    
                    Button(isConnectingToDraft ? "..." : "Connect") {
                        Task {
                            isConnectingToDraft = true
                            await viewModel.connectToManualDraft(draftID: manualDraftID)
                            isConnectingToDraft = false
                        }
                    }
                    .font(.callout)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(manualDraftID.isEmpty || isConnectingToDraft)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: -> Step 3: Active Draft Section
    
    private var activeDraftSection: some View {
        VStack(spacing: 12) {
            // Draft header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let selectedDraft = viewModel.selectedDraft {
                        Text(selectedDraft.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            if viewModel.isLiveMode {
                                HStack(spacing: 4) {
                                    Circle().fill(.green).frame(width: 6, height: 6)
                                    Text("Live")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if !viewModel.allDraftPicks.isEmpty {
                                Text("\(viewModel.allDraftPicks.count) picks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let myRosterID = viewModel.myRosterID {
                                Text("Pick \(myRosterID)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    } else {
                        Text("Manual Draft")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Monitoring picks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Turn indicator or polling status
                if viewModel.isMyTurn {
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("YOUR TURN")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1))
                    .clipShape(Capsule())
                } else if viewModel.isLiveMode {
                    PollingCountdownDial(
                        countdown: viewModel.pollingCountdown,
                        maxInterval: viewModel.maxPollingInterval,
                        isPolling: viewModel.connectionStatus == .connected,
                        onRefresh: {
                            Task { await viewModel.forceRefresh() }
                        }
                    )
                }
            }
            
            // Manual position picker (if needed)
            if viewModel.manualDraftNeedsPosition {
                manualPositionPicker
            }
        }
        .padding()
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: -> Manual Position Picker
    
    private var manualPositionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                Text("Select your draft position:")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            // Position grid
            let teamCount = viewModel.maxTeamsInDraft
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(teamCount, 6))
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...teamCount, id: \.self) { position in
                    Button("\(position)") {
                        viewModel.selectedManualPosition = position
                    }
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(width: 40, height: 40)
                    .background(
                        viewModel.selectedManualPosition == position ? 
                        Color.blue : Color(.systemGray5)
                    )
                    .foregroundColor(
                        viewModel.selectedManualPosition == position ? 
                        .white : .primary
                    )
                    .clipShape(Circle())
                }
            }
            
            HStack(spacing: 12) {
                Button("Set Position \(viewModel.selectedManualPosition)") {
                    viewModel.setManualDraftPosition(viewModel.selectedManualPosition)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Skip") {
                    viewModel.dismissManualPositionPrompt()
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Main Body (Redesigned for Sports App Flow)
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // STEP 1: Collapsible Connect Section (Always Visible but Collapsed by Default)
                quickConnectSection
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                
                // STEP 2: Draft Selection (Show if connected)
                if viewModel.connectionStatus == .connected {
                    draftSelectionSection
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                
                // STEP 3: Active Draft Status (Show if draft selected)
                if viewModel.selectedDraft != nil || viewModel.isConnectedToManualDraft {
                    activeDraftSection
                        .padding(.horizontal) 
                        .padding(.bottom, 20)
                }
                
                // STEP 4: Player Suggestions (Main Content)
                suggestionsSection
                    .padding(.horizontal)
            }
        }
        // Remove navigation title completely
        .background(Color(.systemGroupedBackground))
        
        // Auto-connect on appear
        .onAppear {
            // Auto-connect to default services on page load
            if viewModel.connectionStatus != .connected {
                Task {
                    // Connect to both Sleeper and ESPN with default user
                    await viewModel.connectWithUsernameOrID(AppConstants.GpSleeperID)
                    // Note: ESPN connection will be available as a separate service
                }
            }
        }
        
        // MARK: - Sheets and Alerts (unchanged)
        .alert("YOUR TURN!", isPresented: $viewModel.showingPickAlert) {
            Button("Got It!") { viewModel.dismissPickAlert() }
            Button("View Suggestions") { viewModel.dismissPickAlert() }
        } message: {
            Text(viewModel.pickAlertMessage)
        }
        
        .alert("Pick Confirmed", isPresented: $viewModel.showingConfirmationAlert) {
            Button("Nice!") { viewModel.dismissConfirmationAlert() }
        } message: {
            Text(viewModel.confirmationAlertMessage)
        }
        
        .sheet(isPresented: $viewModel.showingESPNPickPrompt) {
            ESPNDraftPickSelectionView(
                leagueName: viewModel.pendingESPNLeagueWrapper?.league.name ?? "ESPN League",
                maxTeams: viewModel.maxTeamsInDraft,
                selectedPick: $viewModel.selectedESPNDraftPosition,
                onConfirm: { pick in
                    Task { await viewModel.setESPNDraftPosition(pick) }
                },
                onCancel: { viewModel.cancelESPNPositionSelection() }
            )
        }
        
        .sheet(isPresented: $showingPlayerStats) {
            if let player = selectedPlayerForStats,
               let sleeperPlayer = findSleeperPlayer(for: player) {
                PlayerStatsCardView(player: sleeperPlayer, team: NFLTeam.team(for: player.team))
            }
        }
    }
    
    // MARK: -> Helper Methods
    
    @ViewBuilder
    private func playerImageForSuggestion(_ player: Player) -> some View {
        // Try multiple lookup strategies to find the Sleeper player
        if let sleeperPlayer = findSleeperPlayerForSuggestion(player) {
            PlayerImageView(
                player: sleeperPlayer,
                size: 60,
                team: NFLTeam.team(for: player.team)
            )
        } else {
            // Fallback with team colors
            Circle()
                .fill(NFLTeam.team(for: player.team)?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(player.firstInitial)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(NFLTeam.team(for: player.team)?.accentColor ?? .white)
                )
                .frame(width: 60, height: 60)
        }
    }
    
    private func findSleeperPlayerForSuggestion(_ player: Player) -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        // Strategy 1: Direct ID match (works for real Sleeper data)
        if let directMatch = PlayerDirectoryStore.shared.players[player.id] {
            return directMatch
        }
        
        // Strategy 2: Name + position + team match (works for seed data)
        let nameMatch = allSleeperPlayers.first { sleeperPlayer in
            let nameMatches = sleeperPlayer.shortName.lowercased() == "\(player.firstInitial) \(player.lastName)".lowercased()
            let positionMatches = sleeperPlayer.position?.uppercased() == player.position.rawValue
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return nameMatches && positionMatches && teamMatches
        }
        
        if let nameMatch = nameMatch {
            return nameMatch
        }
        
        // Strategy 3: Fuzzy name match (handles slight differences)
        let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
            guard let sleeperFirst = sleeperPlayer.firstName,
                  let sleeperLast = sleeperPlayer.lastName else { return false }
            
            let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == player.firstInitial.uppercased()
            let lastNameMatches = sleeperLast.lowercased().contains(player.lastName.lowercased()) || 
                                   player.lastName.lowercased().contains(sleeperLast.lowercased())
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return firstInitialMatches && lastNameMatches && teamMatches
        }
        
        if let fuzzyMatch = fuzzyMatch {
            return fuzzyMatch
        }
        
        return nil
    }
    
    // MARK: -> Player Stats Integration
    
    private func showPlayerStats(for player: Player) {
        selectedPlayerForStats = player
        // Use async dispatch to ensure state is updated before presenting sheet
        DispatchQueue.main.async {
            showingPlayerStats = true
        }
    }
    
    // MARK: -> Player Action Handlers
    
    private func addPlayerToFeed(_ suggestion: Suggestion) {
        // Add to the picks feed (other people's picks)
        let currentFeed = viewModel.picksFeed.isEmpty ? "" : viewModel.picksFeed + ", "
        viewModel.picksFeed = currentFeed + suggestion.player.shortKey
        viewModel.addFeedPick()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func lockPlayerAsPick(_ suggestion: Suggestion) {
        // Lock as your own pick
        viewModel.myPickInput = suggestion.player.shortKey
        viewModel.lockMyPick()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    // MARK: -> Player Details Row
    private func playerDetailsRow(for player: Player) -> some View {
        HStack(spacing: 8) {
            // Try to get Sleeper player data for detailed info
            if let sleeperPlayer = findSleeperPlayerForSuggestion(player) {
                // Fantasy Rank
                if let searchRank = sleeperPlayer.searchRank {
                    Text("FantRnk: \(searchRank)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Years of experience
                if let yearsExp = sleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Injury status (red text if present)
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                   Text(String(injuryStatus.prefix(5)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                // Fallback when no Sleeper data
                Text("Tier \(player.tier) • \(player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: -> Player Details Row for "All" view (with FantRnk restored)
    private func playerDetailsRowForAll(for player: Player) -> some View {
        HStack(spacing: 8) {
            // Try to get Sleeper player data for detailed info
            if let sleeperPlayer = findSleeperPlayerForSuggestion(player) {
                // Fantasy Rank (restored)
                if let searchRank = sleeperPlayer.searchRank {
                    Text("FantRnk: \(searchRank)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Jersey number  
                if let number = sleeperPlayer.number {
                    Text("#: \(number)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Years of experience
                if let yearsExp = sleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Injury status (red text if present)
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                   Text(String(injuryStatus.prefix(5)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                // Fallback when no Sleeper data
                Text("Tier \(player.tier) • \(player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: -> Player Name and Position View
    
    private func playerNameAndPositionView(for suggestion: Suggestion) -> some View {
        HStack(spacing: 6) {
            // Player name - smaller font
            Text("\(suggestion.player.firstInitial) \(suggestion.player.lastName)")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Position (smaller font) - only show if no positional rank available
            if let sleeperPlayer = findSleeperPlayerForSuggestion(suggestion.player),
               let positionRank = sleeperPlayer.positionalRank {
                // Show positional rank instead of basic position
                Text("- \(positionRank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            } else {
                // Fallback to basic position if no positional rank
                Text("- \(suggestion.player.position.rawValue)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func tierBadge(_ tier: Int) -> some View {
        Text("T\(tier)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(tierColor(tier))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .purple        // Elite players - purple background
        case 2: return .blue          // Very good players - blue  
        case 3: return .orange        // Decent players - orange
        default: return .gray         // Deep/bench players - gray
        }
    }

    private func findSleeperPlayer(for player: Player) -> SleeperPlayer? {
        return findSleeperPlayerForSuggestion(player)
    }
}

// MARK: -> Conditional Swipe Actions Extension

extension View {
    @ViewBuilder
    func conditionalSwipeActions<T: View, L: View>(
        condition: Bool,
        @ViewBuilder trailing: () -> T,
        @ViewBuilder leading: () -> L
    ) -> some View {
        if condition {
            self.swipeActions(edge: .trailing, content: trailing)
                .swipeActions(edge: .leading, content: leading)
        } else {
            self
        }
    }
}

#Preview {
    NavigationView {
        DraftRoomView(viewModel: DraftRoomViewModel())
    }
}