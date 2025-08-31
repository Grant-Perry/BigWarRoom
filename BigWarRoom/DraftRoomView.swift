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
    @Binding var selectedTab: Int

    // MARK: -> State variables
    @State private var customSleeperInput: String = AppConstants.GpSleeperID
    @State private var showAllLeagues = false
    @State private var manualDraftID: String = ""
    @State private var isConnectingToDraft = false
    @State private var selectedPlayerForStats: Player?
    @State private var showingPlayerStats = false
    @State private var showConnectionSection = false // Default closed
    @State private var selectedYear: String = "2025" // Add year selection state

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
                    // Year picker section
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Season Year")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Picker("Season Year", selection: $selectedYear) {
                            ForEach(AppConstants.availableYears, id: \.self) { year in
                                Text(year).tag(year)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedYear) { newYear in
                            // Update AppConstants when year changes
                            AppConstants.ESPNLeagueYear = newYear
                            
                            // Reconnect if already connected to get new year's data
                            if viewModel.connectionStatus == .connected {
                                Task {
                                    await viewModel.connectWithUsernameOrID(customSleeperInput, season: newYear)
                                }
                            }
                        }
                    }
                    
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
                                    await viewModel.connectWithUsernameOrID(customSleeperInput, season: selectedYear)
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
                                Task { 
                                    // Update ESPN year before connecting
                                    AppConstants.ESPNLeagueYear = selectedYear
                                    await viewModel.connectToESPNOnly() 
                                }
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
                .onAppear {
                    // Auto-expand when leagues are available
                    if !viewModel.allAvailableDrafts.isEmpty {
                        showAllLeagues = true
                    }
                }
                .onChange(of: viewModel.allAvailableDrafts.count) { newCount in
                    // Auto-expand when leagues become available
                    if newCount > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllLeagues = true
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
                
                // STEP 4: Draft Actions & Quick Tools
                if viewModel.selectedDraft != nil || viewModel.isConnectedToManualDraft {
                    draftQuickActionsSection
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("War Room")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        
        // Auto-connect on appear
        .onAppear {
            // Auto-connect to default services on page load
            if viewModel.connectionStatus != .connected {
                Task {
                    // Connect to both Sleeper and ESPN with default user using 2025 season
                    await viewModel.connectWithUsernameOrID(AppConstants.GpSleeperID, season: selectedYear)
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
    
    // MARK: -> Draft Quick Actions Section
    
    private var draftQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
            
            // Action buttons grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
            
            LazyVGrid(columns: columns, spacing: 12) {
                // Navigate to AI Suggestions
                Button {
                    selectedTab = 1 // Switch to AI Picks tab
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("AI Picks")
                            .font(.callout)
                            .fontWeight(.medium)
                        
                        Text("Smart suggestions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Navigate to Draft Board
                Button {
                    selectedTab = 3 // Switch to Draft Board tab
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "sportscourt")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text("Draft Board")
                            .font(.callout)
                            .fontWeight(.medium)
                        
                        Text("Round by round")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Navigate to Live Picks
                Button {
                    selectedTab = 2 // Switch to Live Picks tab
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Live Picks")
                            .font(.callout)
                            .fontWeight(.medium)
                        
                        Text("Real-time updates")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Navigate to My Roster
                Button {
                    selectedTab = 4 // Switch to My Roster tab
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("My Roster")
                            .font(.callout)
                            .fontWeight(.medium)
                        
                        Text("Team overview")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Draft stats summary (if connected)
            if !viewModel.allDraftPicks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Draft Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.allDraftPicks.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Total Picks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isMyTurn {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("YOUR TURN")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                Text("Make your pick!")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Waiting")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text("Other managers")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Top 25 AI Suggestions Section
            topSuggestionsSection
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: -> Top Suggestions Section
    
    private var topSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top AI Suggestions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !viewModel.suggestions.isEmpty {
                    Text("Showing \(min(viewModel.suggestions.count, 5))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.suggestions.isEmpty {
                // Loading state
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading AI suggestions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                // Show top 5 suggestions in compact format
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.suggestions.prefix(5)) { suggestion in
                        compactSuggestionCard(suggestion)
                    }
                }
                
                // "View All" button to navigate to AI Picks tab
                if viewModel.suggestions.count > 5 {
                    Button {
                        selectedTab = 1 // Switch to AI Picks tab
                    } label: {
                        HStack {
                            Text("View All \(viewModel.suggestions.count) Suggestions")
                                .font(.callout)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    // MARK: -> Compact Suggestion Card
    
    private func compactSuggestionCard(_ suggestion: Suggestion) -> some View {
        HStack(spacing: 10) {
            // Player headshot (smaller)
            playerImageForSuggestion(suggestion.player, size: 40)
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(suggestion.player.firstInitial) \(suggestion.player.lastName)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // Position
                    if let sleeperPlayer = findSleeperPlayerForSuggestion(suggestion.player),
                       let positionRank = sleeperPlayer.positionalRank {
                        Text(positionRank)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(positionColor(suggestion.player.position))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Text(suggestion.player.position.rawValue)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(positionColor(suggestion.player.position))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    
                    Spacer()
                    
                    // Team logo (smaller)
                    TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                        .frame(width: 24, height: 24)
                }
                
                // Fantasy rank and tier
                HStack(spacing: 6) {
                    if let sleeperPlayer = findSleeperPlayerForSuggestion(suggestion.player),
                       let searchRank = sleeperPlayer.searchRank {
                        Text("Rank \(searchRank)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    
                    Text("Tier \(suggestion.player.tier)")
                        .font(.caption2)
                        .foregroundColor(tierColor(suggestion.player.tier))
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
                .opacity(0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            showPlayerStats(for: suggestion.player)
        }
        .contextMenu {
            Button("Lock as My Pick") {
                lockPlayerAsPick(suggestion)
            }
            
            Button("Add to Feed") {
                addPlayerToFeed(suggestion)
            }
            
            Button("View Stats") {
                showPlayerStats(for: suggestion.player)
            }
        }
    }

    // MARK: -> Helper Methods
    
    @ViewBuilder
    private func playerImageForSuggestion(_ player: Player, size: CGFloat = 60) -> some View {
        if let sleeperPlayer = findSleeperPlayerForSuggestion(player) {
            PlayerImageView(
                player: sleeperPlayer,
                size: size,
                team: NFLTeam.team(for: player.team)
            )
        } else {
            Circle()
                .fill(NFLTeam.team(for: player.team)?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(player.firstInitial)
                        .font(.system(size: size/2.5, weight: .bold))
                        .foregroundColor(NFLTeam.team(for: player.team)?.accentColor ?? .white)
                )
                .frame(width: size, height: size)
        }
    }
    
    private func findSleeperPlayerForSuggestion(_ player: Player) -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        if let directMatch = PlayerDirectoryStore.shared.players[player.id] {
            return directMatch
        }
        
        let nameMatch = allSleeperPlayers.first { sleeperPlayer in
            let nameMatches = sleeperPlayer.shortName.lowercased() == "\(player.firstInitial) \(player.lastName)".lowercased()
            let positionMatches = sleeperPlayer.position?.uppercased() == player.position.rawValue
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return nameMatches && positionMatches && teamMatches
        }
        
        if let nameMatch = nameMatch {
            return nameMatch
        }
        
        let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
            guard let sleeperFirst = sleeperPlayer.firstName,
                  let sleeperLast = sleeperPlayer.lastName else { return false }
            
            let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == player.firstInitial.uppercased()
            let lastNameMatches = sleeperLast.lowercased().contains(player.lastName.lowercased()) || 
                                   player.lastName.lowercased().contains(sleeperLast.lowercased())
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return firstInitialMatches && lastNameMatches && teamMatches
        }
        
        return fuzzyMatch
    }
    
    private func showPlayerStats(for player: Player) {
        selectedPlayerForStats = player
        DispatchQueue.main.async {
            showingPlayerStats = true
        }
    }
    
    private func addPlayerToFeed(_ suggestion: Suggestion) {
        let currentFeed = viewModel.picksFeed.isEmpty ? "" : viewModel.picksFeed + ", "
        viewModel.picksFeed = currentFeed + suggestion.player.shortKey
        viewModel.addFeedPick()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func lockPlayerAsPick(_ suggestion: Suggestion) {
        viewModel.myPickInput = suggestion.player.shortKey
        viewModel.lockMyPick()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func positionColor(_ position: Position) -> Color {
        switch position.rawValue.uppercased() {
        case "QB": return .purple
        case "RB": return .green
        case "WR": return .blue
        case "TE": return .orange
        case "K": return .gray
        case "DEF": return .red
        default: return .gray
        }
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .purple
        case 2: return .blue
        case 3: return .orange
        default: return .gray
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
        DraftRoomView(viewModel: DraftRoomViewModel(), selectedTab: .constant(0))
    }
}