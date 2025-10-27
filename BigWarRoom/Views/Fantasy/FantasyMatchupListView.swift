//
//  FantasyMatchupListView.swift  
//  BigWarRoom
//
// MARK: -> Fantasy Matchup List View (MVVM Coordinator)

import SwiftUI

struct FantasyMatchupListView: View {
    let draftRoomViewModel: DraftRoomViewModel
    @State private var viewModel = FantasyViewModel.shared
    @State private var weekManager = WeekSelectionManager.shared
    @State private var fantasyMatchupListViewModel: FantasyMatchupListViewModel
    
    init(draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
        // 🔥 PHASE 3: Use @State for @Observable ViewModels
        self._fantasyMatchupListViewModel = State(wrappedValue: FantasyMatchupListViewModel())
    }

    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle(fantasyMatchupListViewModel.shouldHideTitle() ? "" : (viewModel.selectedLeague?.league.name ?? "Fantasy"))
                .navigationBarTitleDisplayMode(fantasyMatchupListViewModel.shouldHideTitle() ? .inline : .large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        weekButton
                    }
                }
                .preferredColorScheme(.dark)
                .sheet(isPresented: $viewModel.showWeekSelector) {
                    weekPickerSheet
                }
                .sheet(isPresented: $fantasyMatchupListViewModel.showDraftPositionPicker) {
                    draftPositionSheet
                }
                .task {
                    // Only run once on initial load
                    if !fantasyMatchupListViewModel.hasInitializedSmartMode {
                        await fantasyMatchupListViewModel.smartModeDetection()
                        fantasyMatchupListViewModel.hasInitializedSmartMode = true
                    }
                }
                .onChange(of: draftRoomViewModel.selectedLeagueWrapper) { _, newLeague in
                    handleLeagueChange(newLeague)
                }
                .onAppear {
                    setupViewModels()
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay {
            leaguePickerOverlay
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            // Smart Mode Content
            if fantasyMatchupListViewModel.shouldShowLeaguePicker {
                // ALL LEAGUES MODE: Show gorgeous picker overlay
                Color.clear // Transparent background for overlay
            } else if fantasyMatchupListViewModel.shouldShowDraftPositionPicker {
                // DRAFT POSITION MODE: Show position picker
                Color.clear // Transparent background for sheet
            } else {
                // SINGLE LEAGUE MODE: Normal Fantasy view
                singleLeagueContent
            }
        }
        .padding(.horizontal, 16) // THIS adds padding to the entire fucking screen content!
    }
    
    @ViewBuilder
    private var singleLeagueContent: some View {
        FantasySingleLeagueContentView(
            draftRoomViewModel: draftRoomViewModel,
            weekManager: weekManager,
            fantasyViewModel: viewModel,
            fantasyMatchupListViewModel: fantasyMatchupListViewModel,
            forceChoppedMode: $fantasyMatchupListViewModel.forceChoppedMode
        )
        .padding(.horizontal, 24) // Increased from 20 to bring it in more
        .padding(.top, 10) // Added top padding
    }
    
    @ViewBuilder
    private var weekButton: some View {
        Button("Week \(weekManager.selectedWeek)") {
            viewModel.presentWeekSelector()
        }
        .font(.headline)
        .foregroundColor(.blue)
    }
    
    @ViewBuilder
    private var weekPickerSheet: some View {
        WeekPickerView(
            weekManager: weekManager,
            isPresented: $viewModel.showWeekSelector
        )
    }
    
    @ViewBuilder
    private var draftPositionSheet: some View {
        if let league = fantasyMatchupListViewModel.selectedLeagueForPosition {
            ESPNDraftPickSelectionSheet.forDraft(
                leagueName: league.league.name,
                maxTeams: league.league.totalRosters,
                selectedPosition: $fantasyMatchupListViewModel.selectedDraftPosition,
                onConfirm: { position in
                    fantasyMatchupListViewModel.confirmDraftPosition(league, position: position)
                },
                onCancel: {
                    fantasyMatchupListViewModel.cancelDraftPositionSelection()
                }
            )
        }
    }
    
    @ViewBuilder
    private var leaguePickerOverlay: some View {
        if fantasyMatchupListViewModel.showLeaguePicker {
            LeaguePickerOverlay(
                leagues: fantasyMatchupListViewModel.availableLeagues,
                onLeagueSelected: { selectedLeague in
                    fantasyMatchupListViewModel.selectLeagueFromPicker(selectedLeague)
                },
                onDismiss: {
                    fantasyMatchupListViewModel.showLeaguePicker = false
                }
            )
            .zIndex(1000) // Ensure it's on top
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleLeagueChange(_ newLeague: UnifiedLeagueManager.LeagueWrapper?) {
        // Only react to actual changes, not repeat values
        guard !fantasyMatchupListViewModel.isSettingUpLeague else {
            print("🔄 LEAGUE CHANGE: Ignoring during setup")
            return
        }
        
        print("🔄 LEAGUE CHANGE DETECTED: \(newLeague?.league.name ?? "nil")")
        
        // Debounce this call to prevent rapid fire
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            if !fantasyMatchupListViewModel.isDetectingSmartMode && !fantasyMatchupListViewModel.isSettingUpLeague {
                await fantasyMatchupListViewModel.smartModeDetection()
            }
        }
    }
    
    private func setupViewModels() {
        // Pass the shared DraftRoomViewModel to both ViewModels
        fantasyMatchupListViewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
        viewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
    }
}