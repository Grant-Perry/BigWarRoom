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
                        ForEach(DraftRoomViewModel.PositionFilter.allCases) { filter in
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
                ForEach(DraftRoomViewModel.SortMethod.allCases) { method in
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
    
    // MARK: -> Live Connection Status
    
    private var liveStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: viewModel.isLiveMode ? "wifi.circle.fill" : "wifi.circle")
                    .foregroundColor(viewModel.isLiveMode ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isLiveMode ? "Live Draft Mode" : "Connected")
                        .font(.headline)
                        .foregroundColor(viewModel.isLiveMode ? .green : .orange)
                    
                    // Show connected user info
                    if !viewModel.sleeperDisplayName.isEmpty {
                        Text(viewModel.sleeperDisplayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Polling countdown dial
                if viewModel.isLiveMode && viewModel.selectedDraft != nil {
                    PollingCountdownDial(
                        countdown: viewModel.pollingCountdown,
                        maxInterval: viewModel.maxPollingInterval,
                        isPolling: viewModel.connectionStatus == .connected,
                        onRefresh: {
                            Task {
                                await viewModel.forceRefresh()
                            }
                        }
                    )
                }
                
                Button("Disconnect") {
                    viewModel.disconnectFromLive()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            if let selectedDraft = viewModel.selectedDraft,
               let draftID = selectedDraft.draftID {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monitoring: \(selectedDraft.name)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 8) {
                        Text("ID: \(String(draftID.suffix(12)))")
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                        
                        // Show pick count if any
                        if !viewModel.allDraftPicks.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(viewModel.allDraftPicks.count) picks made")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding()
        .background(viewModel.isLiveMode ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12));
    }
    
    // MARK: -> Connection Section
    
    @State private var customSleeperInput: String = AppConstants.GpSleeperID
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleeper Account")
                    .font(.headline)
                
                Spacer()
                
                // Manual refresh button
                Button("Refresh") {
                    Task {
                        await viewModel.connectWithUsernameOrID(customSleeperInput)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            if viewModel.connectionStatus == .connected && !viewModel.sleeperDisplayName.isEmpty {
                // Connected - show user info
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.sleeperDisplayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("@\(viewModel.sleeperUsername)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Button("Disconnect") {
                        viewModel.disconnectFromLive()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Not connected - show connect option with username/ID input
                VStack(spacing: 12) {
                    Text("Enter your Sleeper username or User ID to see your league drafts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username or User ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("e.g. 'gpick' or '1117588009542615040'", text: $customSleeperInput)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            
                            Button("Connect") {
                                Task {
                                    await viewModel.connectWithUsernameOrID(customSleeperInput)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(customSleeperInput.isEmpty)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button("Use Default (Gp)") {
                            customSleeperInput = AppConstants.GpSleeperID
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Button("Paste") {
                            if let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) {
                                customSleeperInput = clipboardText
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Username: gpick")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("User ID: ...\(String(AppConstants.GpSleeperID.suffix(8)))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fontDesign(.monospaced)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: -> Available Drafts (Now Collapsible)
    
    @State private var showAvailableDrafts = false
    
    private var availableDraftsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Dropdown Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAvailableDrafts.toggle()
                }
            } label: {
                HStack {
                    Text("Available Drafts")
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(viewModel.allAvailableDrafts.count) drafts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: showAvailableDrafts ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .foregroundColor(.primary)
            
            // Collapsible Content
            if showAvailableDrafts {
                if viewModel.allAvailableDrafts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("No drafts found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Connect to your Sleeper account to see league drafts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.allAvailableDrafts) { draft in
                            DraftSelectionCard(
                                draft: draft,
                                isSelected: draft.id == viewModel.selectedDraft?.id,
                                onSelect: {
                                    Task {
                                        await viewModel.selectDraft(draft)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: -> Live Draft Picks Feed
    
    private var liveDraftPicksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Draft Picks")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.allDraftPicks.isEmpty {
                    Text("\(viewModel.allDraftPicks.count) picks made")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.allDraftPicks.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "clock.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Waiting for draft picks...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Picks will appear here as they happen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Live picks grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 3) // Even more spacing
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) { // Even more vertical spacing
                        ForEach(viewModel.allDraftPicks.reversed()) { pick in // Reverse to show most recent first
                            DraftPickCard(
                                pick: pick,
                                isRecent: viewModel.recentLivePicks.contains { $0.playerID == pick.player.playerID }
                            )
                        }
                    }
                    .padding(.horizontal, 20) // Even more horizontal padding
                }
                .frame(maxHeight: 400) // Increased height to accommodate larger cards
                .background(Color(.systemGray6).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: -> Manual Draft ID Entry
    
    @State private var manualDraftID: String = ""
    @State private var isConnectingToDraft = false
    // Remove the local @State and use viewModel's @Published property instead
    
    private var manualDraftIDSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show connected state only after position is selected or roster is found
            if viewModel.isConnectedToManualDraft && 
               !viewModel.manualDraftNeedsPosition && 
               !viewModel.showManualDraftEntry {
                // Connected state - minimized green card
                connectedManualDraftCard
            } else {
                // Not connected or still configuring - show entry form
                manualDraftEntryForm
            }
        }
    }
    
    // MARK: - Connected Manual Draft Card
    
    private var connectedManualDraftCard: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected to Manual Draft")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                if let draft = viewModel.manualDraftInfo {
                    // Show draft name and ID
                    if let draftName = draft.metadata?.name {
                        Text(draftName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        Text("ID: \(String(draft.draftID.suffix(12)))")
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("ID: \(String(draft.draftID.suffix(12)))")
                            .font(.subheadline)
                            .fontDesign(.monospaced)
                            .foregroundColor(.white.opacity(0.9))
                    }
                } else if let selectedDraft = viewModel.selectedDraft,
                          let draftID = selectedDraft.draftID {
                    // Fallback to selectedDraft info
                    Text("ID: \(String(draftID.suffix(12)))")
                        .font(.subheadline)
                        .fontDesign(.monospaced)
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Text("Manual draft monitoring active")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            Spacer()
            
            Button("Disconnect") {
                viewModel.disconnectFromLive()
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .background(.green) // Using .green for the connected state
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Manual Draft Entry Form
    
    private var manualDraftEntryForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Dropdown Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showManualDraftEntry.toggle() // Use viewModel property
                }
            } label: {
                HStack {
                    Text("Manual Draft Entry")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("For mock/other drafts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: viewModel.showManualDraftEntry ? "chevron.up" : "chevron.down") // Use viewModel property
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            // Collapsible Content
            if viewModel.showManualDraftEntry { // Use viewModel property
                VStack(alignment: .leading, spacing: 12) {
                    // Simplified explanation - no green/orange status boxes
                    Text("Enter any draft ID to monitor picks and get suggestions")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Enter Draft ID", text: $manualDraftID)
                            .textFieldStyle(.roundedBorder)
                            .fontDesign(.monospaced)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .disabled(isConnectingToDraft)
                        
                        Button(isConnectingToDraft ? "Connecting..." : "Connect") {
                            Task {
                                await connectToManualDraftID(manualDraftID)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(manualDraftID.isEmpty || isConnectingToDraft)
                    }
                    
                    // Manual Position Picker (show when needed)
                    if viewModel.manualDraftNeedsPosition {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                Text("What's your draft position?")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            
                            Text("Select your draft slot to enable pick alerts:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Use button grid instead of picker for better touch interaction
                            let teamCount = viewModel.manualDraftInfo?.settings?.teams ??
                                          viewModel.selectedDraft?.settings?.teams ??
                                          viewModel.selectedDraft?.totalRosters ??
                                          16
                            
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
                            
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(1...teamCount, id: \.self) { position in
                                    Button {
                                        viewModel.selectedManualPosition = position
                                    } label: {
                                        Text("\(position)")
                                            .font(.system(size: 16, weight: .medium))
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
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    HStack(spacing: 8) {
                        Button("Clear") {
                            manualDraftID = ""
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 6));
                        
                        Button("Paste") {
                            if let clipboardText = UIPasteboard.general.string {
                                let numbersOnly = clipboardText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                if numbersOnly.count >= 18 {
                                    manualDraftID = numbersOnly
                                } else {
                                    manualDraftID = clipboardText
                                }
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func connectToManualDraftID(_ draftID: String) async {
        guard !draftID.isEmpty else { return }
        
        isConnectingToDraft = true
        await viewModel.connectToManualDraft(draftID: draftID)
        isConnectingToDraft = false
    }
    
    // MARK: -> Manual Input
    
    @State private var showManualInput = false
    
    private var manualInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Dropdown Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showManualInput.toggle()
                }
            } label: {
                HStack {
                    Text("Manual Player Input")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Track picks manually")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: showManualInput ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            // Collapsible Content
            if showManualInput {
                VStack(spacing: 16) {
                    // Picks Feed Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Picks (comma-separated)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("E.g. J Jefferson, L Jackson, J Allen", text: $viewModel.picksFeed)
                                .textFieldStyle(.roundedBorder)
                                .fontDesign(.monospaced)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .submitLabel(.done)
                                .onSubmit {
                                    viewModel.addFeedPick()
                                }
                            Button("Add") {
                                viewModel.addFeedPick()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    // My Pick Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I picked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("E.g. J Burrow", text: $viewModel.myPickInput)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(false)
                                .submitLabel(.done)
                                .onSubmit {
                                    viewModel.lockMyPick()
                                }
                            Button("Lock") {
                                viewModel.lockMyPick()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
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
    
    @State private var selectedPlayerForStats: Player?
    @State private var showingPlayerStats = false
    
    private func showPlayerStats(for player: Player) {
        selectedPlayerForStats = player
        // Use async dispatch to ensure state is updated before presenting sheet
        DispatchQueue.main.async {
            showingPlayerStats = true
        }
    }
    
    private func statsPreview(for player: Player) -> some View {
        Group {
            // Get Sleeper player data for richer display
            if let sleeperPlayer = PlayerDirectoryStore.shared.players[player.id] {
                HStack(spacing: 8) {
                    // Show years of experience
                    if let yearsExp = sleeperPlayer.yearsExp {
                        Text("Y\(yearsExp)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show search rank as fantasy relevance
                    if let searchRank = sleeperPlayer.searchRank {
                        Text("#\(searchRank)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    
                    // Show injury status if any
                    if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
					   Text(String(injuryStatus.prefix(5)))
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            } else {
                HStack(spacing: 8) {
                    if let team = NFLTeam.team(for: player.team) {
                        Text(team.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
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

    // MARK: -> Helpers
    
    func label(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
    }

    func value(_ player: Player?) -> some View {
        Text(player?.shortKey ?? "—")
            .font(.body)
            .fontWeight(.medium)
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
    
    private func positionalRankBadge(_ positionRank: String) -> some View {
        Text(positionRank)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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

    // MARK: -> Main Body (Simplified - No NavigationView Wrapper)
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Connection status (show first if connected)
                if viewModel.connectionStatus == .connected {
                    liveStatusCard
                }
                
                // Sleeper Account section (only show if NOT connected to avoid duplication)
                if viewModel.connectionStatus != .connected {
                    connectionSection
                }
                
                // Available drafts (show if connected) - now collapsible
                if viewModel.connectionStatus == .connected {
                    availableDraftsSection
                }
                
                // Manual draft ID entry
                manualDraftIDSection
                
                // Manual input section
                manualInputSection
                
                // Suggestions (main section)
                suggestionsSection
            }
            .padding()
        }
        .navigationTitle("Draft War Room")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        
        // MARK: - Pick Alerts
        .alert("🚨 YOUR TURN!", isPresented: $viewModel.showingPickAlert) {
            Button("Got It!") {
                viewModel.dismissPickAlert()
            }
            Button("View Suggestions") {
                viewModel.dismissPickAlert()
            }
        } message: {
            Text(viewModel.pickAlertMessage)
        }
        
        .alert("Pick Confirmed", isPresented: $viewModel.showingConfirmationAlert) {
            Button("Nice!") {
                viewModel.dismissConfirmationAlert()
            }
        } message: {
            Text(viewModel.confirmationAlertMessage)
        }
        
        // Player stats sheet
        .sheet(isPresented: $showingPlayerStats) {
            if let player = selectedPlayerForStats,
               let sleeperPlayer = findSleeperPlayer(for: player) {
                PlayerStatsCardView(
                    player: sleeperPlayer,
                    team: NFLTeam.team(for: player.team)
                )
            }
        }
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