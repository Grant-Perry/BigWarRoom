//
//  AppSettingsView.swift
//  BigWarRoom
//
//  Main settings and configuration view for existing users
//

import SwiftUI

struct AppSettingsView: View {
   @State private var viewModel: SettingsViewModel
   @Environment(NFLWeekService.self) private var nflWeekService
   @Environment(WeekSelectionManager.self) private var weekSelectionManager
   @Environment(BettingOddsService.self) private var bettingOddsService // 🔥 NEW: For odds refresh
   
   // MARK: - @AppStorage Properties
   @AppStorage("UseRedesignedPlayerCards") private var useRedesignedCards = false
   @AppStorage("MatchupsHub_UseBarLayout") private var useBarLayout = false
   @AppStorage("MatchupCacheEnabled") private var matchupCacheEnabled = true
   @AppStorage("PreferredSportsbook") private var preferredSportsbookRaw: String = Sportsbook.bestLine.rawValue
   @AppStorage("MatchupRefresh") private var matchupRefresh: Int = 15
   @AppStorage("WinProbabilitySD") private var winProbabilitySD: Double = 40.0
   @AppStorage("OddsRefreshInterval") private var oddsRefreshInterval: Double = 15.0 // 🔥 NEW: Minutes between odds refreshes
   
   // MARK: - Section State
   @State private var isGeneralExpanded = true
   @State private var isAppearanceExpanded = false
   @State private var isFeaturesExpanded = false
   @State private var isNFLSettingsExpanded = false
   @State private var isServicesExpanded = false
   @State private var isDataManagementExpanded = false
   @State private var isDeveloperExpanded = false
   @State private var isAboutExpanded = false
   
   @State private var showWeekPicker = false
   
   init(nflWeekService: NFLWeekService) {
      _viewModel = State(wrappedValue: SettingsViewModel(nflWeekService: nflWeekService))
   }
   
   var body: some View {
      NavigationView {
         List {
            GeneralSettingsSection(
               isExpanded: $isGeneralExpanded,
               autoRefreshEnabled: $viewModel.autoRefreshEnabled,
               matchupRefresh: $matchupRefresh,
               keepAppActive: $viewModel.keepAppActive,
               showEliminatedChoppedLeagues: $viewModel.showEliminatedChoppedLeagues,
               showEliminatedPlayoffLeagues: $viewModel.showEliminatedPlayoffLeagues,
               onAutoRefreshChange: { _ in },
               onKeepActiveChange: viewModel.updateKeepAppActive,
               onChoppedChange: viewModel.updateShowEliminatedChoppedLeagues,
               onPlayoffChange: viewModel.updateShowEliminatedPlayoffLeagues
            )
            
            AppearanceSettingsSection(
               isExpanded: $isAppearanceExpanded,
               useRedesignedCards: $useRedesignedCards,
               useBarLayout: $useBarLayout,
               matchupCacheEnabled: $matchupCacheEnabled
            )
            
            FeatureSettingsSection(
               isExpanded: $isFeaturesExpanded,
               lineupThreshold: $viewModel.lineupOptimizationThreshold,
               winProbabilitySD: $winProbabilitySD,
               preferredSportsbook: $preferredSportsbookRaw,
               oddsRefreshInterval: $oddsRefreshInterval, // 🔥 NEW: Pass odds refresh interval
               onThresholdReset: viewModel.resetLineupOptimizationThreshold,
               onThresholdChange: viewModel.updateLineupOptimizationThreshold,
               onOddsRefresh: {
                  bettingOddsService.refreshGameOddsCache()
               }
            )
            
            NFLSettingsSection(
               isExpanded: $isNFLSettingsExpanded,
               showWeekPicker: $showWeekPicker,
               currentWeek: weekSelectionManager.selectedWeek, // 🔥 FIXED: Read from WeekSelectionManager
               currentYear: SeasonYearManager.shared.selectedYear, // 🔥 FIXED: Read from SeasonYearManager
               onRefresh: { await nflWeekService.refresh() }
            )
            
            FantasyServicesSection(
               isExpanded: $isServicesExpanded,
               espnStatus: viewModel.espnStatus,
               espnHasCredentials: viewModel.espnHasCredentials,
               sleeperStatus: viewModel.sleeperStatus,
               sleeperHasCredentials: viewModel.sleeperHasCredentials,
               onDisconnectESPN: viewModel.disconnectESPN,
               onDisconnectSleeper: viewModel.disconnectSleeper,
               onConnectDefault: viewModel.connectToDefaultServices
            )
            
            DataManagementSection(
               isExpanded: $isDataManagementExpanded,
               onClearCache: viewModel.requestClearAllCache,
               onClearCredentials: viewModel.requestClearAllServices,
               onFactoryReset: viewModel.requestClearAllPersistedData
            )
            
            DeveloperSettingsSection(
               isExpanded: $isDeveloperExpanded,
               debugModeEnabled: $viewModel.debugModeEnabled,
               espnHasCredentials: viewModel.espnHasCredentials,
               isTestingConnection: viewModel.isTestingConnection,
               onTestESPN: viewModel.testESPNConnection,
               onExportLogs: viewModel.exportDebugLogs
            )
            
            AboutSection(isExpanded: $isAboutExpanded)
         }
         .navigationTitle("Settings")
         .navigationBarTitleDisplayMode(.automatic)
         .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
               Button("Mission Control") {
                  NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
               }
               .font(.subheadline)
               .fontWeight(.medium)
               .foregroundColor(Color.gpGreen)
            }
         }
         .onAppear {
            viewModel.refreshConnectionStatus()
         }
         .alert("Confirm Clear Action", isPresented: $viewModel.showingClearConfirmation) {
            Button("Clear", role: .destructive) {
               viewModel.confirmClearAction()
            }
            Button("Cancel", role: .cancel) {
               viewModel.cancelClearAction()
            }
         } message: {
            Text("Are you sure you want to clear this data? This action cannot be undone.")
         }
         .alert("Action Result", isPresented: $viewModel.showingClearResult) {
            Button("OK") {
               viewModel.dismissClearResult()
            }
         } message: {
            Text(viewModel.clearResultMessage)
         }
      }
      
      if showWeekPicker {
         WeekPickerView(
            weekManager: weekSelectionManager,
            yearManager: SeasonYearManager.shared,
            isPresented: $showWeekPicker
         )
      }
   }
}