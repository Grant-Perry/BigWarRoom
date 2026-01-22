//
//  AppSettingsView.swift
//  BigWarRoom
//
//  Main settings and configuration view for existing users
//

import SwiftUI

struct AppSettingsView: View {
   @State private var settingsViewModel: SettingsViewModel
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
   @AppStorage("OddsRefreshInterval") private var oddsRefreshInterval: Double = 30.0
   
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
      _settingsViewModel = State(wrappedValue: SettingsViewModel(nflWeekService: nflWeekService))
   }
   
   var body: some View {
      NavigationView {
         List {
            GeneralSettingsSection(
               isExpanded: $isGeneralExpanded,
               autoRefreshEnabled: $settingsViewModel.autoRefreshEnabled,
               matchupRefresh: $matchupRefresh,
               keepAppActive: $settingsViewModel.keepAppActive,
               showEliminatedChoppedLeagues: $settingsViewModel.showEliminatedChoppedLeagues,
               showEliminatedPlayoffLeagues: $settingsViewModel.showEliminatedPlayoffLeagues,
               onAutoRefreshChange: { _ in },
               onKeepActiveChange: settingsViewModel.updateKeepAppActive,
               onChoppedChange: settingsViewModel.updateShowEliminatedChoppedLeagues,
               onPlayoffChange: settingsViewModel.updateShowEliminatedPlayoffLeagues
            )
            
            AppearanceSettingsSection(
               isExpanded: $isAppearanceExpanded,
               useRedesignedCards: $useRedesignedCards,
               useBarLayout: $useBarLayout,
               matchupCacheEnabled: $matchupCacheEnabled
            )
            
            FeatureSettingsSection(
               isExpanded: $isFeaturesExpanded,
               lineupThreshold: $settingsViewModel.lineupOptimizationThreshold,
               winProbabilitySD: $winProbabilitySD,
               preferredSportsbook: $preferredSportsbookRaw,
               oddsRefreshInterval: $oddsRefreshInterval, // 🔥 NEW: Pass odds refresh interval
               onThresholdReset: settingsViewModel.resetLineupOptimizationThreshold,
               onThresholdChange: settingsViewModel.updateLineupOptimizationThreshold,
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
               espnStatus: settingsViewModel.espnStatus,
               espnHasCredentials: settingsViewModel.espnHasCredentials,
               sleeperStatus: settingsViewModel.sleeperStatus,
               sleeperHasCredentials: settingsViewModel.sleeperHasCredentials,
               onDisconnectESPN: settingsViewModel.disconnectESPN,
               onDisconnectSleeper: settingsViewModel.disconnectSleeper,
               onConnectDefault: settingsViewModel.connectToDefaultServices
            )
            
            DataManagementSection(
               isExpanded: $isDataManagementExpanded,
               onClearCache: settingsViewModel.requestClearAllCache,
               onClearCredentials: settingsViewModel.requestClearAllServices,
               onFactoryReset: settingsViewModel.requestClearAllPersistedData
            )
            
            DeveloperSettingsSection(
               isExpanded: $isDeveloperExpanded,
               debugModeEnabled: $settingsViewModel.debugModeEnabled,
               espnHasCredentials: settingsViewModel.espnHasCredentials,
               isTestingConnection: settingsViewModel.isTestingConnection,
               onTestESPN: settingsViewModel.testESPNConnection,
               onExportLogs: settingsViewModel.exportDebugLogs
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
            settingsViewModel.refreshConnectionStatus()
         }
         .alert("Confirm Clear Action", isPresented: $settingsViewModel.showingClearConfirmation) {
            Button("Clear", role: .destructive) {
               settingsViewModel.confirmClearAction()
            }
            Button("Cancel", role: .cancel) {
               settingsViewModel.cancelClearAction()
            }
         } message: {
            Text("Are you sure you want to clear this data? This action cannot be undone.")
         }
         .alert("Action Result", isPresented: $settingsViewModel.showingClearResult) {
            Button("OK") {
               settingsViewModel.dismissClearResult()
            }
         } message: {
            Text(settingsViewModel.clearResultMessage)
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
