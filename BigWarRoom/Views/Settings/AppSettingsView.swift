//
//  AppSettingsView.swift
//  BigWarRoom
//
//  Main settings and configuration view for existing users
//  Test comment to verify code-apply tool is working
//  SECOND TEST: Xcode is open with file open - testing file locking
//

import SwiftUI

struct AppSettingsView: View {
   @State private var viewModel: SettingsViewModel
   @State private var showingConnectionSuccess = false
   @State private var connectionSuccessMessage = ""
   @Environment(NFLWeekService.self) private var nflWeekService

	  // 🎨 WOODY'S REDESIGN TOGGLE
   @AppStorage("UseRedesignedPlayerCards") private var useRedesignedCards = false

	  // 🔥 NEW: Bar-style layout toggle for Mission Control
   @AppStorage("MatchupsHub_UseBarLayout") private var useBarLayout = false
   
   // 🚀 NEW: Matchup caching toggle
   @AppStorage("MatchupCacheEnabled") private var matchupCacheEnabled = true

	  // 🎰 Preferred sportsbook for odds display
   @AppStorage("PreferredSportsbook") private var preferredSportsbookRaw: String = Sportsbook.bestLine.rawValue

	  // 📊 Win Probability SD - local binding for proper SwiftUI observation
   @AppStorage("WinProbabilitySD") private var winProbabilitySD: Double = 40.0

	  // 🔥 NEW: Collapsible section state
   // MARK: Intentionally collapsed on init
   @State private var isServicesExpanded = false
   @State private var isAppSettingsExpanded = true
   @State private var isDeveloperExpanded = false
   @State private var isDataManagementExpanded = false
   @State private var isAboutExpanded = false

	  // 📊 Win Probability SD description
   private var winProbabilityDescription: String {
	  let sd = winProbabilitySD
	  if sd <= 20 {
		 return "Aggressive (big leads = high %)"
	  } else if sd <= 35 {
		 return "Moderate"
	  } else if sd <= 50 {
		 return "ESPN-like (balanced)"
	  } else {
		 return "Conservative (stays near 50%)"
	  }
   }

   init(nflWeekService: NFLWeekService) {
      _viewModel = State(wrappedValue: SettingsViewModel(nflWeekService: nflWeekService))
   }

   var body: some View {
	  NavigationView {
		 List {

			   // MARK: -> App Settings (Collapsible)
			Section {
			   Button {
				  withAnimation {
					 isAppSettingsExpanded.toggle()
				  }
			   } label: {
				  HStack {
					 Text("App Settings")
						.font(.headline)
						.foregroundColor(.white)

					 Spacer()

					 Image(systemName: isAppSettingsExpanded ? "chevron.up" : "chevron.down")
						.foregroundColor(.secondary)
						.font(.system(size: 14, weight: .semibold))
				  }
			   }
			   .buttonStyle(.plain)

			   if isAppSettingsExpanded {
					 // Auto-Refresh Settings
				  HStack {
					 Image(systemName: "arrow.clockwise")
						.foregroundColor(.blue)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Auto-Refresh")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Refresh interval: \(AppConstants.MatchupRefresh)s")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Toggle("", isOn: $viewModel.autoRefreshEnabled)
						.labelsHidden()
				  }

					 // Keep App Active Toggle
				  HStack {
					 Image(systemName: "iphone.slash")
						.foregroundColor(.gpGreen)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Keep App Active")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Prevent auto-lock while using the app")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Toggle("", isOn: $viewModel.keepAppActive)
						.labelsHidden()
						.onChange(of: viewModel.keepAppActive) { _, newValue in
						   viewModel.updateKeepAppActive(newValue)
						}
				  }

					 // Show Eliminated Chopped Leagues Toggle
				  HStack {
					 Image(systemName: "eye.slash.fill")
						.foregroundColor(.orange)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Show Eliminated Chopped Leagues")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Display leagues where you've been eliminated")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Toggle("", isOn: $viewModel.showEliminatedChoppedLeagues)
						.labelsHidden()
						.onChange(of: viewModel.showEliminatedChoppedLeagues) { _, newValue in
						   viewModel.updateShowEliminatedChoppedLeagues(newValue)
						}
				  }

					 // Show Eliminated Playoff Leagues Toggle
				  HStack {
					 Image(systemName: "trophy.slash")
						.foregroundColor(.red)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Show Eliminated Playoff Leagues")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Display regular leagues where you're out of playoffs")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Toggle("", isOn: $viewModel.showEliminatedPlayoffLeagues)
						.labelsHidden()
						.onChange(of: viewModel.showEliminatedPlayoffLeagues) { _, newValue in
						   viewModel.updateShowEliminatedPlayoffLeagues(newValue)
						}
				  }

					 // Modern Sports App Design Toggle
				  HStack {
					 Image(systemName: "sparkles")
						.foregroundColor(.gpYellow)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Modern Player Card Design")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Thin, horizontal layout inspired by ESPN/Sleeper")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Toggle("", isOn: $useRedesignedCards)
						.labelsHidden()
				  }

					 // Bar-style layout toggle for Mission Control
				  HStack {
					 Image(systemName: "rectangle.stack.fill")
						.foregroundColor(.blue)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Mission Control Bar Layout")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Modern horizontal bars for matchups")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Toggle("", isOn: $useBarLayout)
						.labelsHidden()
				  }
				  
				  // 🚀 NEW: Matchup Caching Toggle
				  VStack(alignment: .leading, spacing: 12) {
					 HStack {
						Image(systemName: "bolt.fill")
						   .foregroundColor(.gpGreen)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Enable Matchup Caching")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text("Cache matchup structure per week for faster loading")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}

						Spacer()

						Toggle("", isOn: $matchupCacheEnabled)
						   .labelsHidden()
						   .onChange(of: matchupCacheEnabled) { _, newValue in
							  MatchupCacheManager.shared.setCacheEnabled(newValue)
						   }
					 }
					 
					 // Show cache info and clear button when enabled
					 if matchupCacheEnabled {
						VStack(alignment: .leading, spacing: 8) {
						   HStack {
							  Image(systemName: "info.circle.fill")
								 .foregroundColor(.blue.opacity(0.7))
								 .font(.system(size: 12))
							  
							  if let cacheInfo = MatchupCacheManager.shared.getCacheInfo() {
								 Text(cacheInfo)
									.font(.caption2)
									.foregroundColor(.secondary)
							  } else {
								 Text("No cached data yet")
									.font(.caption2)
									.foregroundColor(.secondary)
							  }
							  
							  Spacer()
							  
							  Text(MatchupCacheManager.shared.getCacheSizeString())
								 .font(.caption2)
								 .foregroundColor(.secondary)
						   }
						   
						   Button(role: .destructive) {
							  MatchupCacheManager.shared.clearAllCache()
						   } label: {
							  HStack {
								 Image(systemName: "trash.fill")
									.font(.system(size: 12))
								 Text("Clear Matchup Cache")
									.font(.caption)
							  }
							  .foregroundColor(.red)
							  .padding(.vertical, 6)
							  .padding(.horizontal, 12)
							  .background(Color.red.opacity(0.1))
							  .cornerRadius(6)
						   }
						}
						.padding(.leading, 32)
						.padding(.top, 4)
					 }
				  }
				  .padding(.vertical, 4)

				  // Sportsbook Preference for Schedule Odds
				  VStack(alignment: .leading, spacing: 12) {
					 HStack {
						Image(systemName: "dollarsign.circle.fill")
						   .foregroundColor(.green)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Odds Source")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text("Which sportsbook lines to display on Schedule")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}
					 }

						// Grid of sportsbook badges
					 LazyVGrid(columns: [
						GridItem(.flexible()),
						GridItem(.flexible()),
						GridItem(.flexible()),
						GridItem(.flexible())
					 ], spacing: 8) {
						ForEach(Sportsbook.allCases) { book in
						   Button {
							  preferredSportsbookRaw = book.rawValue
						   } label: {
							  VStack(spacing: 4) {
								 Text(book.abbreviation)
									.font(.system(size: 12, weight: .black, design: .rounded))
									.foregroundColor(book.textColor)
									.frame(width: 40, height: 24)
									.background(
									   RoundedRectangle(cornerRadius: 4)
										  .fill(book.primaryColor)
									)
									.overlay(
									   RoundedRectangle(cornerRadius: 4)
										  .stroke(preferredSportsbookRaw == book.rawValue ? Color.white : Color.clear, lineWidth: 2)
									)

								 Text(book == .bestLine ? "Best" : book.abbreviation)
									.font(.system(size: 9, weight: .medium))
									.foregroundColor(preferredSportsbookRaw == book.rawValue ? .white : .secondary)
							  }
						   }
						   .buttonStyle(.plain)
						}
					 }
					 .padding(.leading, 32)
				  }
				  .padding(.vertical, 4)

					 // Lineup Optimization Threshold
				  VStack(alignment: .leading, spacing: 12) {
					 HStack {
						Image(systemName: "cross.case.fill")
						   .foregroundColor(.gpGreen)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Lineup RX Threshold")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text("Only suggest moves with \(Int(viewModel.lineupOptimizationThreshold))%+ improvement")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}

						Spacer()

						   // Reset button
						Button(action: {
						   viewModel.resetLineupOptimizationThreshold()
						}) {
						   Text("Reset")
							  .font(.caption)
							  .foregroundColor(.gpBlue)
							  .padding(.horizontal, 8)
							  .padding(.vertical, 4)
							  .background(Color.gpBlue.opacity(0.1))
							  .cornerRadius(6)
						}
						.opacity(viewModel.lineupOptimizationThreshold == 10.0 ? 0.5 : 1.0)
						.disabled(viewModel.lineupOptimizationThreshold == 10.0)
					 }

						// Slider with percentage labels
					 VStack(spacing: 8) {
						Slider(value: $viewModel.lineupOptimizationThreshold, in: 10...100, step: 5)
						   .tint(.gpGreen)
						   .onChange(of: viewModel.lineupOptimizationThreshold) { _, newValue in
							  viewModel.updateLineupOptimizationThreshold(newValue)
						   }

						HStack {
						   Text("10%")
							  .font(.caption2)
							  .foregroundColor(.secondary)
						   Spacer()
						   Text("50%")
							  .font(.caption2)
							  .foregroundColor(.secondary)
						   Spacer()
						   Text("100%")
							  .font(.caption2)
							  .foregroundColor(.secondary)
						}
					 }
					 .padding(.horizontal, 28)
				  }
				  .padding(.vertical, 8)

					 // Win Probability Standard Deviation
				  VStack(alignment: .leading, spacing: 12) {
					 HStack {
						Image(systemName: "chart.bar.fill")
						   .foregroundColor(.purple)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Win Probability Model")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text("SD: \(Int(winProbabilitySD)) – \(winProbabilityDescription)")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}

						Spacer()

						   // Reset button
						Button(action: {
						   winProbabilitySD = 40.0
						}) {
						   Text("Reset")
							  .font(.caption)
							  .foregroundColor(.gpBlue)
							  .padding(.horizontal, 8)
							  .padding(.vertical, 4)
							  .background(Color.gpBlue.opacity(0.1))
							  .cornerRadius(6)
						}
						.opacity(winProbabilitySD == 40.0 ? 0.5 : 1.0)
						.disabled(winProbabilitySD == 40.0)
					 }

						// Slider with current value badge
					 VStack(spacing: 8) {
						HStack {
						   Slider(value: $winProbabilitySD, in: 10...80, step: 1)
							  .tint(.purple)

							  // Current value badge
						   Text("\(Int(winProbabilitySD))")
							  .font(.system(size: 14, weight: .bold, design: .rounded))
							  .foregroundColor(.white)
							  .frame(width: 36, height: 28)
							  .background(
								 RoundedRectangle(cornerRadius: 6)
									.fill(Color.purple)
							  )
						}

						HStack {
						   Text("10")
							  .font(.caption2)
							  .foregroundColor(.secondary)
						   Text("Aggressive")
							  .font(.caption2)
							  .foregroundColor(.gpGreen)
						   Spacer()
						   Text("40")
							  .font(.caption2)
							  .foregroundColor(.secondary)
						   Spacer()
						   Text("Conservative")
							  .font(.caption2)
							  .foregroundColor(.orange)
						   Text("80")
							  .font(.caption2)
							  .foregroundColor(.secondary)
						}
					 }
					 .padding(.horizontal, 28)
				  }
				  .padding(.vertical, 8)

					 // NFL Week Override
				  NavigationLink {
					 NFLWeekSettingsView()
				  } label: {
					 HStack {
						Image(systemName: "calendar")
						   .foregroundColor(.orange)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("NFL Week Settings")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text("Current: Week \(viewModel.currentNFLWeek)")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}
					 }
				  }

					 // Year Selection
				  HStack {
					 Image(systemName: "calendar.circle")
						.foregroundColor(.purple)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Season Year")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Fantasy season to use")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Picker("Season", selection: $viewModel.selectedYear) {
						ForEach(viewModel.availableYears, id: \.self) { year in
						   Text(year).tag(year)
						}
					 }
					 .pickerStyle(.menu)
				  }
			   }
			} footer: {
			   if isAppSettingsExpanded {
				  Text("Configure app behavior and data refresh settings.")
			   }
			}


			   // MARK: -> Quick Navigation (Always Visible)
			Section {
			   Button {
				  NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
			   } label: {
				  HStack(spacing: 12) {
					 ZStack {
						Circle()
						   .fill(Color.gpGreen.opacity(0.1))
						   .frame(width: 28, height: 28)

						Image(systemName: "target")
						   .foregroundColor(Color.gpGreen)
						   .font(.system(size: 16, weight: .semibold))
					 }

					 VStack(alignment: .leading, spacing: 2) {
						Text("Go to Mission Control")
						   .font(.subheadline)
						   .fontWeight(.medium)
						   .foregroundColor(Color.gpGreen)

						Text("View your fantasy matchups and leagues")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Image(systemName: "arrow.right")
						.foregroundColor(Color.gpGreen)
						.font(.system(size: 14, weight: .semibold))
				  }
			   }
			} header: {
			   Text("Navigation")
			} footer: {
			   Text("Connected to your leagues? Head to Mission Control to view matchups!")
			}

			   // MARK: -> Service Configuration (Collapsible)
			Section {
			   Button {
				  withAnimation {
					 isServicesExpanded.toggle()
				  }
			   } label: {
				  HStack {
					 Text("Fantasy Services")
						.font(.headline)
						.foregroundColor(.white)

					 Spacer()

					 Image(systemName: isServicesExpanded ? "chevron.up" : "chevron.down")
						.foregroundColor(.secondary)
						.font(.system(size: 14, weight: .semibold))
				  }
			   }
			   .buttonStyle(.plain)

			   if isServicesExpanded {
					 // ESPN Section
				  NavigationLink {
					 ESPNSetupView()
				  } label: {
					 HStack(spacing: 12) {
						AppConstants.espnLogo
						   .frame(width: 28, height: 28)

						VStack(alignment: .leading, spacing: 2) {
						   Text("ESPN Fantasy")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text(viewModel.espnStatus)
							  .font(.caption)
							  .foregroundColor(viewModel.espnHasCredentials ? .green : .secondary)
						}

						Spacer()

						if viewModel.espnHasCredentials {
						   Image(systemName: "checkmark.circle.fill")
							  .foregroundColor(.green)
							  .font(.system(size: 16))

						   Button("Disconnect") {
							  viewModel.disconnectESPN()
						   }
						   .font(.caption)
						   .foregroundColor(.red)
						   .padding(.horizontal, 8)
						   .padding(.vertical, 4)
						   .background(Color.red.opacity(0.1))
						   .cornerRadius(6)
						   .onTapGesture {
							  viewModel.disconnectESPN()
						   }
						}
					 }
				  }

					 // Sleeper Section
				  NavigationLink {
					 SleeperSetupView()
				  } label: {
					 HStack(spacing: 12) {
						AppConstants.sleeperLogo
						   .frame(width: 28, height: 28)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Sleeper Fantasy")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text(viewModel.sleeperStatus)
							  .font(.caption)
							  .foregroundColor(viewModel.sleeperHasCredentials ? .green : .secondary)
						}

						Spacer()

						if viewModel.sleeperHasCredentials {
						   Image(systemName: "checkmark.circle.fill")
							  .foregroundColor(.green)
							  .font(.system(size: 16))

						   Button("Disconnect") {
							  viewModel.disconnectSleeper()
						   }
						   .font(.caption)
						   .foregroundColor(.red)
						   .padding(.horizontal, 8)
						   .padding(.vertical, 4)
						   .background(Color.red.opacity(0.1))
						   .cornerRadius(6)
						   .onTapGesture {
							  viewModel.disconnectSleeper()
						   }
						}
					 }
				  }

					 // Default Connection Option
				  Button {
					 viewModel.connectToDefaultServices()
				  } label: {
					 HStack(spacing: 12) {
						ZStack {
						   Circle()
							  .fill(.green.opacity(0.1))
							  .frame(width: 28, height: 28)

						   HStack(spacing: 2) {
							  AppConstants.espnLogo
								 .frame(width: 16, height: 16)
							  AppConstants.sleeperLogo
								 .frame(width: 16, height: 16)
						   }
						}

						VStack(alignment: .leading, spacing: 2) {
						   Text("Default Connection (use Gp's leagues!)")
							  .font(.subheadline)
							  .fontWeight(.medium)
							  .foregroundColor(.blue)

						   Text("Auto-connect to both ESPN and Sleeper")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}

						Spacer()

						Image(systemName: "bolt.fill")
						   .foregroundColor(.gpGreen)
						   .font(.system(size: 16))
					 }
				  }
				  .disabled(viewModel.espnHasCredentials && viewModel.sleeperHasCredentials)
			   }
			} footer: {
			   if isServicesExpanded {
				  Text("Connect your ESPN and Sleeper accounts to access leagues and drafts.")
			   }
			}


			   // MARK: -> About Section (Collapsible)
			Section {
			   Button {
				  withAnimation {
					 isAboutExpanded.toggle()
				  }
			   } label: {
				  HStack {
					 Text("About")
						.font(.headline)
						.foregroundColor(.white)

					 Spacer()

					 Image(systemName: isAboutExpanded ? "chevron.up" : "chevron.down")
						.foregroundColor(.secondary)
						.font(.system(size: 14, weight: .semibold))
				  }
			   }
			   .buttonStyle(.plain)

			   if isAboutExpanded {
				  NavigationLink {
					 AboutView()
				  } label: {
					 HStack {
						Image(systemName: "info.circle")
						   .foregroundColor(.blue)
						   .frame(width: 24)

						Text("About BigWarRoom")
						   .font(.subheadline)
						   .fontWeight(.medium)
					 }
				  }

				  HStack {
					 Image(systemName: "number")
						.foregroundColor(.gray)
						.frame(width: 24)

					 Text("Version")
						.font(.subheadline)
						.fontWeight(.medium)

					 Spacer()

					 Text(AppConstants.getVersion())
						.font(.subheadline)
						.foregroundColor(.secondary)
				  }
			   }
			}

			   // MARK: -> Developer Settings (Collapsible)
			Section {
			   Button {
				  withAnimation {
					 isDeveloperExpanded.toggle()
				  }
			   } label: {
				  HStack {
					 Text("Developer")
						.font(.headline)
						.foregroundColor(.white)

					 Spacer()

					 Image(systemName: isDeveloperExpanded ? "chevron.up" : "chevron.down")
						.foregroundColor(.secondary)
						.font(.system(size: 14, weight: .semibold))
				  }
			   }
			   .buttonStyle(.plain)

			   if isDeveloperExpanded {
					 // Debug Mode Toggle
				  HStack {
					 Image(systemName: "ladybug")
						.foregroundColor(.red)
						.frame(width: 24)

					 VStack(alignment: .leading, spacing: 2) {
						Text("Debug Mode")
						   .font(.subheadline)
						   .fontWeight(.medium)

						Text("Show debug info and test features")
						   .font(.caption)
						   .foregroundColor(.secondary)
					 }

					 Spacer()

					 Toggle("", isOn: $viewModel.debugModeEnabled)
						.labelsHidden()
				  }

					 // Test ESPN Connection
				  if viewModel.espnHasCredentials {
					 Button {
						viewModel.testESPNConnection()
					 } label: {
						HStack {
						   Image(systemName: "network")
							  .foregroundColor(.blue)
							  .frame(width: 24)

						   VStack(alignment: .leading, spacing: 2) {
							  Text("Test ESPN Connection")
								 .font(.subheadline)
								 .fontWeight(.medium)

							  Text("Verify ESPN API access")
								 .font(.caption)
								 .foregroundColor(.secondary)
						   }

						   Spacer()

						   if viewModel.isTestingConnection {
							  ProgressView()
								 .scaleEffect(0.8)
						   }
						}
					 }
					 .disabled(viewModel.isTestingConnection)
				  }

					 // Export Debug Logs
				  Button {
					 viewModel.exportDebugLogs()
				  } label: {
					 HStack {
						Image(systemName: "doc.text")
						   .foregroundColor(.gray)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Export Debug Logs")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text("Share app logs for troubleshooting")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}
					 }
				  }
			   }
			} footer: {
			   if isDeveloperExpanded {
				  Text("Advanced settings for debugging and development.")
			   }
			}

			   // MARK: -> Data Management (Collapsible)
			Section {
			   Button {
				  withAnimation {
					 isDataManagementExpanded.toggle()
				  }
			   } label: {
				  HStack {
					 Text("Data Management")
						.font(.headline)
						.foregroundColor(.white)

					 Spacer()

					 Image(systemName: isDataManagementExpanded ? "chevron.up" : "chevron.down")
						.foregroundColor(.secondary)
						.font(.system(size: 14, weight: .semibold))
				  }
			   }
			   .buttonStyle(.plain)

			   if isDataManagementExpanded {
					 // Clear Cache
				  Button {
					 viewModel.requestClearAllCache()
				  } label: {
					 HStack {
						Image(systemName: "trash")
						   .foregroundColor(.orange)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Clear Cache")
							  .font(.subheadline)
							  .fontWeight(.medium)

						   Text("Clear temporary app data")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}
					 }
				  }

					 // Clear All Credentials
				  Button {
					 viewModel.requestClearAllServices()
				  } label: {
					 HStack {
						Image(systemName: "key.slash")
						   .foregroundColor(.red)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Clear All Credentials")
							  .font(.subheadline)
							  .fontWeight(.medium)
							  .foregroundColor(.red)

						   Text("Remove saved login info")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}
					 }
				  }

					 // Nuclear Option
				  Button {
					 viewModel.requestClearAllPersistedData()
				  } label: {
					 HStack {
						Image(systemName: "exclamationmark.triangle")
						   .foregroundColor(.red)
						   .frame(width: 24)

						VStack(alignment: .leading, spacing: 2) {
						   Text("Factory Reset")
							  .font(.subheadline)
							  .fontWeight(.bold)
							  .foregroundColor(.red)

						   Text("Reset app to factory defaults")
							  .font(.caption)
							  .foregroundColor(.secondary)
						}
					 }
				  }
			   }
			} footer: {
			   if isDataManagementExpanded {
				  Text("⚠️ Use with caution. These actions cannot be undone.")
			   }
			}
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
   }
}

   // MARK: -> NFL Week Settings View

struct NFLWeekSettingsView: View {
   @Environment(NFLWeekService.self) private var nflWeekService
   @Environment(\.dismiss) private var dismiss

   var body: some View {
	  List {
		 Section {
			HStack {
			   Text("Current Week")
			   Spacer()
			   Text("Week \(nflWeekService.currentWeek)")
				  .foregroundColor(.secondary)
			}

			HStack {
			   Text("Current Year")
			   Spacer()
			   Text(nflWeekService.currentYear)
				  .foregroundColor(.secondary)
			}
		 } header: {
			Text("Current NFL Schedule")
		 } footer: {
			Text("Automatically calculated based on the current date and NFL season schedule.")
		 }

		 Section {
			Button("Refresh NFL Schedule") {
			   Task {
				  await nflWeekService.refresh()
			   }
			}
		 } footer: {
			Text("Force refresh the current NFL week calculation.")
		 }
	  }
	  .navigationTitle("NFL Week Settings")
	  .navigationBarTitleDisplayMode(.inline)
   }
}