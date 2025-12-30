//
//  OpponentIntelligenceDashboardView.swift
//  BigWarRoom
//
//  #GoodNav Template - Intelligence matching Mission Control exactly
//

import SwiftUI

/// **Opponent Intelligence Dashboard - #GoodNav Template**
/// 
/// Strategic opponent analysis across all leagues
struct OpponentIntelligenceDashboardView: View {
    // 🔥 PHASE 3 DI: Use @Environment for ViewModels instead of creating with .shared
    @Environment(MatchupsHubViewModel.self) private var matchupsHub
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    
    // 🔥 PHASE 3 DI: Create ViewModel using @State
    @State private var viewModel: OpponentIntelligenceViewModel?
    @State private var watchService = PlayerWatchService.shared
    @State private var showingFilters = false
    @State private var selectedIntelligence: OpponentIntelligence?
    @State private var showingWeekPicker = false
    @State private var showingWatchedPlayers = false
    @State private var selectedMatchup: UnifiedMatchup? // NEW: For matchup navigation
    @State private var showInjuryAlerts = true // NEW: Collapsible section state
    @State private var showGameAlerts = true // DISABLED: Game alerts section state
    @State private var showThreatAlerts = true // NEW: Collapsible section state
    @State private var showThreatMatrix = true // NEW: Collapsible section state
    @State private var showConflictAlerts = true // NEW: Collapsible section state
    @State private var showOpponentPlayers = true // NEW: Collapsible section state
    
    // NEW: Info sheet states
    @State private var showingInjuryAlertsInfo = false
    @State private var showingGameAlertsInfo = false // DISABLED: Game alerts info sheet
    @State private var showingThreatAlertsInfo = false  
    @State private var showingThreatMatrixInfo = false
    @State private var showingConflictsInfo = false
    @State private var showingOpponentPlayersInfo = false
    
    // Computed properties for display values
    private var currentThreatLevelDisplay: String {
        guard let vm = viewModel else { return "All" }
        switch vm.selectedThreatLevel {
        case .critical: return "Critical"
        case .high: return "High" 
        case .medium: return "Medium"
        case .low: return "Low"
        case .none: return "All"
        }
    }

    private var currentSortByDisplay: String {
        viewModel?.sortBy.rawValue ?? "Score"
    }

    private var conflictsOnlyDisplay: String {
        (viewModel?.showConflictsOnly ?? false) ? "Yes" : "No"
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: 0) {
                // #GoodNav Header (matching Mission Control exactly)
                headerSection
                
                if viewModel?.isLoading == true {
                    loadingView
                } else if viewModel?.opponentIntelligence.isEmpty == true {
                    emptyStateView
                } else {
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // 1. PLAYER INJURY ALERTS (highest priority) - ALWAYS SHOW
                            if let vm = viewModel {
                                playerInjuryAlertsSection(viewModel: vm)
                            }
                            
                            // 2. GAME ALERTS (highest scoring plays per refresh) - DISABLED 🚫
                            
                            // 3. CRITICAL THREAT ALERTS (strategic recommendations excluding injuries)
                            if let vm = viewModel, !vm.nonInjuryRecommendations.isEmpty {
                                criticalThreatAlertsSection(viewModel: vm)
                            }
                            
                            // 4. THREAT MATRIX
                            if let vm = viewModel {
                                threatMatrixSection(viewModel: vm)
                            }
                            
                            // 5. CONFLICT ALERTS
                            if let vm = viewModel, !vm.conflictPlayers.isEmpty {
                                conflictsSection(viewModel: vm)
                            }
                            
                            // 6. ALL OPPONENT PLAYERS
                            if let vm = viewModel {
                                opponentPlayersSection(viewModel: vm)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Tab bar space
                    }
                }
            }
        }
        .onAppear {
            // Initialize viewModel with environment dependencies
            if viewModel == nil {
                viewModel = OpponentIntelligenceViewModel(
                    matchupsHubViewModel: matchupsHub,
                    allLivePlayersViewModel: allLivePlayersViewModel
                )
            }
        }
        .task {
            if let vm = viewModel {
                await vm.loadOpponentIntelligence()
            }
        }
        .refreshable {
            if let vm = viewModel {
                await vm.manualRefresh()
            }
        }
        .onChange(of: viewModel?.lastUpdateTime ?? Date()) {
            if let vm = viewModel {
                watchService.updateWatchedPlayerScores(vm.allOpponentPlayers)
            }
        }
        .sheet(item: $selectedIntelligence) { intelligence in
            OpponentDetailSheet(intelligence: intelligence)
        }
        .sheet(isPresented: $showingFilters) {
            if let vm = viewModel {
                OpponentFiltersSheet(viewModel: vm)
            }
        }
        .sheet(isPresented: $showingWeekPicker) {
            WeekPickerView(
                weekManager: WeekSelectionManager.shared,
                isPresented: $showingWeekPicker
            )
        }
        .sheet(isPresented: $showingWatchedPlayers) {
            WatchedPlayersSheet(watchService: watchService)
        }
        .sheet(item: $selectedMatchup) { matchup in
            MatchupDetailSheetsView(matchup: matchup)
        }
        .sheet(isPresented: $showingInjuryAlertsInfo) {
            IntelligenceSectionInfoSheet(sectionType: .injuryAlerts)
        }
        .sheet(isPresented: $showingThreatAlertsInfo) {
            IntelligenceSectionInfoSheet(sectionType: .criticalThreatAlerts)
        }
        .sheet(isPresented: $showingThreatMatrixInfo) {
            IntelligenceSectionInfoSheet(sectionType: .threatMatrix)
        }
        .sheet(isPresented: $showingConflictsInfo) {
            IntelligenceSectionInfoSheet(sectionType: .playerConflicts)
        }
        .sheet(isPresented: $showingOpponentPlayersInfo) {
            IntelligenceSectionInfoSheet(sectionType: .allOpponentPlayers)
        }
        .onChange(of: WeekSelectionManager.shared.selectedWeek) { _, newWeek in
            // Nuclear option: Clear ALL caches and force fresh load when week changes
            Task {
                if let vm = viewModel {
                    await vm.weekChangeReload()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        Image("BG2")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.4)
            .ignoresSafeArea(.all)
    }
    
    // #GoodNav: Header section matching Mission Control exactly
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Intelligence")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Opponent Analysis • \(viewModel?.timeAgo(viewModel?.lastUpdateTime ?? Date()) ?? "")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // #GoodNav: WEEK picker with icons row (matching Mission Control)
            weekPickerWithIconsRow
        }
        .padding(.horizontal, 20)
        .padding(.top, 8) // REDUCED from 20 to 8 to eliminate excess space
        .padding(.bottom, 16)
    }
    
    // #GoodNav: Week picker with Intelligence icons (matching Mission Control)
    private var weekPickerWithIconsRow: some View {
        HStack {
            // WEEK picker (left side)
            Button(action: { showingWeekPicker = true }) {
                HStack(spacing: 6) {
                    Text("WEEK \(WeekSelectionManager.shared.selectedWeek)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // #GoodNav: Icon controls (right side) - matching Mission Control exactly
            HStack(spacing: 12) {
                // Filters button
                Button(action: { showingFilters = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Watched players button with badge
                Button(action: { showingWatchedPlayers = true }) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(watchService.watchCount > 0 ? .gpOrange : .white)
                        .notificationBadge(count: watchService.watchCount)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Refresh button
                Button(action: { 
                    Task { await viewModel?.manualRefresh() }
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // #GoodNav: Controls section with CONTEXTUAL Intelligence filters
    private var controlsSection: some View {
        HStack {
            // Collapse button (chevron)
            Button(action: {
                // TODO: Add collapse functionality if needed
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // #GoodNav: CONTEXTUAL Intelligence controls
            HStack {
                Spacer()
                
                // Threat Level filter with dropdown
                Menu {
                    Button("All") {
                        viewModel?.setThreatLevelFilter(.none)
                    }
                    Button("Critical") {
                        viewModel?.setThreatLevelFilter(.critical)
                    }
                    Button("High") {
                        viewModel?.setThreatLevelFilter(.high)
                    }
                    Button("Medium") {
                        viewModel?.setThreatLevelFilter(.medium)
                    }
                    Button("Low") {
                        viewModel?.setThreatLevelFilter(.low)
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(currentThreatLevelDisplay)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("Threat Level")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // Position filter with dropdown
                Menu {
                    ForEach(viewModel?.availablePositions ?? ["All"], id: \.self) { position in
                        Button(position) {
                            viewModel?.setPositionFilter(position)
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(viewModel?.selectedPosition ?? "All")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        
                        Text("Position")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // Sort By filter with dropdown
                Menu {
                    ForEach(OpponentIntelligenceViewModel.SortMethod.allCases) { sortMethod in
                        Button(sortMethod.rawValue) {
                            viewModel?.setSortMethod(sortMethod)
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(currentSortByDisplay)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                        
                        Text("Sort by")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // Conflicts Only toggle
                Button(action: { 
                    viewModel?.toggleConflictsOnly()
                }) {
                    VStack(spacing: 2) {
                        Text(conflictsOnlyDisplay)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor((viewModel?.showConflictsOnly ?? false) ? .orange : .gray)
                        
                        Text("Conflicts only")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            
            // Timer dial placeholder (matching Mission Control)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 30, height: 30)
                .overlay(
                    Text("•")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    // MARK: - New Collapsible Sections
    
    /// 1. Player Injury Alerts Section (highest priority)
    private func playerInjuryAlertsSection(viewModel: OpponentIntelligenceViewModel) -> some View {
        CollapsibleSection(
            title: "Player Injury Alerts",
            notice: "NOTICE: Data may continue to update in real-time.",
            count: viewModel.injuryAlerts.count,
            isExpanded: $showInjuryAlerts,
            infoAction: { showingInjuryAlertsInfo = true }
        ) {
            VStack(spacing: 12) {
                // Show injury alerts if we have any
                if !viewModel.injuryAlerts.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.injuryAlerts, id: \.id) { recommendation in
                            InjuryAlertCard(
                                recommendation: recommendation,
                                onNavigateToMatchup: { matchup in
                                    selectedMatchup = matchup
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    /// 2. Critical Threat Alerts Section (non-injury strategic recommendations)
    private func criticalThreatAlertsSection(viewModel: OpponentIntelligenceViewModel) -> some View {
        CollapsibleSection(
            title: "⚠️ Critical Threat Alerts",
            count: viewModel.nonInjuryRecommendations.count,
            isExpanded: $showThreatAlerts,
            infoAction: { showingThreatAlertsInfo = true }
        ) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.nonInjuryRecommendations.prefix(5)) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                        .onTapGesture {
                            handleRecommendationTap(recommendation, viewModel: viewModel)
                        }
                }
            }
        }
    }
    
    /// 3. Enhanced Threat Matrix Section
    private func threatMatrixSection(viewModel: OpponentIntelligenceViewModel) -> some View {
        CollapsibleSection(
            title: "🎯 Threat Matrix",
            count: viewModel.filteredIntelligence.count,
            isExpanded: $showThreatMatrix,
            infoAction: { showingThreatMatrixInfo = true }
        ) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredIntelligence) { intelligence in
                    ThreatMatrixCard(intelligence: intelligence) {
                        // Navigate to matchup instead of showing opponent detail sheet
                        selectedMatchup = intelligence.matchup
                    }
                }
            }
        }
    }
    
    /// 4. Enhanced Conflicts Section
    private func conflictsSection(viewModel: OpponentIntelligenceViewModel) -> some View {
        CollapsibleSection(
            title: "⚔️ Player Conflicts",
            count: viewModel.conflictPlayers.count,
            isExpanded: $showConflictAlerts,
            infoAction: { showingConflictsInfo = true }
        ) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.conflictPlayers.prefix(5)) { conflict in
                    ConflictAlertCard(conflict: conflict)
                }
            }
        }
    }
    
    /// 5. Enhanced Opponent Players Section
    private func opponentPlayersSection(viewModel: OpponentIntelligenceViewModel) -> some View {
        CollapsibleSection(
            title: "👥 All Opponent Players",
            count: viewModel.filteredOpponentPlayers.count,
            isExpanded: $showOpponentPlayers,
            infoAction: { showingOpponentPlayersInfo = true }
        ) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredOpponentPlayers.prefix(20)) { player in
                    OpponentPlayerCard(player: player)
                }
            }
        }
    }
    
    private var loadingView: some View {
        IntelligenceLoadingView()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Opponents Found")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("Connect your leagues in Settings to start tracking opponents")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Navigation Helpers
    
    /// Handle taps on recommendation cards
    private func handleRecommendationTap(_ recommendation: StrategicRecommendation, viewModel: OpponentIntelligenceViewModel) {
        // For Critical Threat Alerts, find the matching intelligence and navigate to its matchup
        if recommendation.title.contains("Critical Threat Alert"),
           let opponentTeam = recommendation.opponentTeam {
            
            // Find the intelligence matching this opponent
            if let intelligence = viewModel.filteredIntelligence.first(where: { intel in
                intel.opponentTeam?.ownerName == opponentTeam.ownerName 
            }) {
                selectedMatchup = intelligence.matchup
            }
        }
        
        // For Injury Alerts, navigate to the specific matchup where the player is rostered
        if recommendation.type == .injuryAlert, let matchup = recommendation.matchup {
            selectedMatchup = matchup
        }
    }
}

#Preview("Intelligence Dashboard - #GoodNav Template") {
    let espnCredentials = ESPNCredentialsManager.shared
    let sleeperCredentials = SleeperCredentialsManager.shared
    let playerDirectory = PlayerDirectoryStore.shared
    let gameStatusService = GameStatusService.shared
    let sharedStatsService = SharedStatsService.shared
    let weekSelectionManager = WeekSelectionManager.shared
    
    let sleeperClient = SleeperAPIClient()
    let espnClient = ESPNAPIClient(credentialsManager: espnCredentials)
    let unifiedLeagueManager = UnifiedLeagueManager(
        sleeperClient: sleeperClient,
        espnClient: espnClient,
        espnCredentials: espnCredentials
    )
    
    let matchupDataStore = MatchupDataStore(
        unifiedLeagueManager: unifiedLeagueManager,
        sharedStatsService: sharedStatsService,
        gameStatusService: gameStatusService,
        weekSelectionManager: weekSelectionManager
    )
    
    let matchupsHub = MatchupsHubViewModel(
        espnCredentials: espnCredentials,
        sleeperCredentials: sleeperCredentials,
        playerDirectory: playerDirectory,
        gameStatusService: gameStatusService,
        sharedStatsService: sharedStatsService,
        matchupDataStore: matchupDataStore
    )
    
    let allLivePlayersViewModel = AllLivePlayersViewModel(
        matchupsHubViewModel: matchupsHub,
        playerDirectory: playerDirectory,
        gameStatusService: gameStatusService,
        sharedStatsService: sharedStatsService,
        weekSelectionManager: weekSelectionManager
    )
    
    OpponentIntelligenceDashboardView()
        .environment(matchupsHub)
        .environment(allLivePlayersViewModel)
        .preferredColorScheme(.dark)
}