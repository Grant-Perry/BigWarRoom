//
//  FantasyMatchupListView.swift  
//  BigWarRoom
//
// MARK: -> Fantasy Matchup List View (MVVM Coordinator)

import SwiftUI

struct FantasyMatchupListView: View {
    let draftRoomViewModel: DraftRoomViewModel
    @Environment(FantasyViewModel.self) private var fantasyViewModel
    @Environment(MatchupsHubViewModel.self) private var matchupsHub
    @State private var weekManager = WeekSelectionManager.shared
    @State private var fantasyMatchupListViewModel: FantasyMatchupListViewModel?
    
    init(draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
    }

    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle(fantasyMatchupListViewModel?.shouldHideTitle() == true ? "" : (fantasyViewModel.selectedLeague?.league.name ?? "Fantasy"))
                .navigationBarTitleDisplayMode(fantasyMatchupListViewModel?.shouldHideTitle() == true ? .inline : .large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        weekButton
                    }
                }
                .preferredColorScheme(.dark)
                .sheet(isPresented: Binding(
                    get: { fantasyViewModel.showWeekSelector },
                    set: { fantasyViewModel.showWeekSelector = $0 }
                )) {
                    weekPickerSheet
                }
                .sheet(isPresented: Binding(
                    get: { fantasyMatchupListViewModel?.showDraftPositionPicker == true },
                    set: { if !$0 { fantasyMatchupListViewModel?.showDraftPositionPicker = false } }
                )) {
                    draftPositionSheet
                }
                .task {
                    // Lazy initialization with dependencies from @Environment
                    if fantasyMatchupListViewModel == nil {
                        fantasyMatchupListViewModel = FantasyMatchupListViewModel(
                            matchupsHubViewModel: matchupsHub,
                            weekManager: weekManager,
                            fantasyViewModel: fantasyViewModel
                        )
                    }
                    
                    // Only run once on initial load
                    if fantasyMatchupListViewModel?.hasInitializedSmartMode == false {
                        await fantasyMatchupListViewModel?.smartModeDetection()
                        fantasyMatchupListViewModel?.hasInitializedSmartMode = true
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
            if fantasyMatchupListViewModel?.shouldShowLeaguePicker == true {
                // ALL LEAGUES MODE: Show gorgeous picker overlay
                Color.clear // Transparent background for overlay
            } else if fantasyMatchupListViewModel?.shouldShowDraftPositionPicker == true {
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
        if let vm = fantasyMatchupListViewModel {
            FantasySingleLeagueContentView(
                draftRoomViewModel: draftRoomViewModel,
                weekManager: weekManager,
                fantasyViewModel: fantasyViewModel,
                fantasyMatchupListViewModel: vm,
                forceChoppedMode: Binding(
                    get: { vm.forceChoppedMode },
                    set: { vm.forceChoppedMode = $0 }
                )
            )
            .padding(.horizontal, 24) // Increased from 20 to bring it in more
            .padding(.top, 10) // Added top padding
        }
    }
    
    @ViewBuilder
    private var weekButton: some View {
        Button("Week \(weekManager.selectedWeek)") {
            fantasyViewModel.presentWeekSelector()
        }
        .font(.headline)
        .foregroundColor(.blue)
    }
    
    @ViewBuilder
    private var weekPickerSheet: some View {
        WeekPickerView(
            weekManager: weekManager,
            isPresented: Binding(
                get: { fantasyViewModel.showWeekSelector },
                set: { fantasyViewModel.showWeekSelector = $0 }
            )
        )
    }
    
    @ViewBuilder
    private var draftPositionSheet: some View {
        if let league = fantasyMatchupListViewModel?.selectedLeagueForPosition,
           let vm = fantasyMatchupListViewModel {
            ESPNDraftPickSelectionSheet.forDraft(
                leagueName: league.league.name,
                maxTeams: league.league.totalRosters,
                selectedPosition: Binding(
                    get: { vm.selectedDraftPosition },
                    set: { vm.selectedDraftPosition = $0 }
                ),
                onConfirm: { position in
                    vm.confirmDraftPosition(league, position: position)
                },
                onCancel: {
                    vm.cancelDraftPositionSelection()
                }
            )
        }
    }
    
    @ViewBuilder
    private var leaguePickerOverlay: some View {
        if fantasyMatchupListViewModel?.showLeaguePicker == true,
           let vm = fantasyMatchupListViewModel {
            LeaguePickerOverlay(
                leagues: vm.availableLeagues,
                onLeagueSelected: { selectedLeague in
                    vm.selectLeagueFromPicker(selectedLeague)
                },
                onDismiss: {
                    vm.showLeaguePicker = false
                }
            )
            .zIndex(1000) // Ensure it's on top
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleLeagueChange(_ newLeague: UnifiedLeagueManager.LeagueWrapper?) {
        // Only react to actual changes, not repeat values
        guard fantasyMatchupListViewModel?.isSettingUpLeague == false else {
            print("🔄 LEAGUE CHANGE: Ignoring during setup")
            return
        }
        
        print("🔄 LEAGUE CHANGE DETECTED: \(newLeague?.league.name ?? "nil")")
        
        // Debounce this call to prevent rapid fire
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            if fantasyMatchupListViewModel?.isDetectingSmartMode == false && fantasyMatchupListViewModel?.isSettingUpLeague == false {
                await fantasyMatchupListViewModel?.smartModeDetection()
            }
        }
    }
    
    private func setupViewModels() {
        // Pass the shared DraftRoomViewModel to both ViewModels
        fantasyMatchupListViewModel?.setSharedDraftRoomViewModel(draftRoomViewModel)
        // FantasyViewModel is now from @Environment, no need to call setSharedDraftRoomViewModel
    }
}