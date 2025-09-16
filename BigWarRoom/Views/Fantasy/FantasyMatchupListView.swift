//
//  FantasyMatchupListView.swift  
//  BigWarRoom
//
// MARK: -> Fantasy Matchup List View (MVVM Coordinator)

import SwiftUI

struct FantasyMatchupListView: View {
    let draftRoomViewModel: DraftRoomViewModel
    @StateObject private var viewModel = FantasyViewModel.shared
    @StateObject private var weekManager = WeekSelectionManager.shared
    @StateObject private var fantasyMatchupListViewModel: FantasyMatchupListViewModel
    
    init(draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
        self._fantasyMatchupListViewModel = StateObject(wrappedValue: FantasyMatchupListViewModel())
    }

    var body: some View {
        NavigationView {
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
                    FantasySingleLeagueContentView(
                        draftRoomViewModel: draftRoomViewModel,
                        weekManager: weekManager,
                        fantasyViewModel: viewModel,
                        fantasyMatchupListViewModel: fantasyMatchupListViewModel,
                        forceChoppedMode: $fantasyMatchupListViewModel.forceChoppedMode
                    )
                }
            }
            .navigationTitle(fantasyMatchupListViewModel.shouldHideTitle() ? "" : (viewModel.selectedLeague?.league.name ?? "Fantasy"))
            .navigationBarTitleDisplayMode(fantasyMatchupListViewModel.shouldHideTitle() ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Week \(weekManager.selectedWeek)") {
                        viewModel.presentWeekSelector()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $viewModel.showWeekSelector) {
                WeekPickerView(
                    isPresented: $viewModel.showWeekSelector
                )
            }
            .sheet(isPresented: $fantasyMatchupListViewModel.showDraftPositionPicker) {
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
            .task {
                // Only run once on initial load
                if !fantasyMatchupListViewModel.hasInitializedSmartMode {
                    await fantasyMatchupListViewModel.smartModeDetection()
                    fantasyMatchupListViewModel.hasInitializedSmartMode = true
                }
            }
            .onReceive(draftRoomViewModel.$selectedLeagueWrapper) { newLeague in
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
            .onAppear {
                // Pass the shared DraftRoomViewModel to both ViewModels
                fantasyMatchupListViewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
                viewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay {
            // League Picker Overlay
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
    }
}