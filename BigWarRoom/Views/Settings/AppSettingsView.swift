//
//  AppSettingsView.swift
//  BigWarRoom
//
//  Main settings and configuration view for existing users
//

import SwiftUI

struct AppSettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showingConnectionSuccess = false
    @State private var connectionSuccessMessage = ""
    @State private var nflWeekService = NFLWeekService.shared
    
    // 🎨 WOODY'S REDESIGN TOGGLE
    @AppStorage("UseRedesignedPlayerCards") private var useRedesignedCards = false
    
    // 🔥 NEW: Bar-style layout toggle for Mission Control
    @AppStorage("MatchupsHub_UseBarLayout") private var useBarLayout = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: -> Quick Navigation
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
                
                // MARK: -> Service Configuration
                Section {
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
                                
                                // 🔥 FIX: Disconnect button inside NavigationLink - use onTapGesture to prevent navigation
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
                                
                                // 🔥 FIX: Disconnect button inside NavigationLink - use onTapGesture to prevent navigation
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
                    
                    // 🔥 NEW: Default Connection Option
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
                    
                } header: {
                    Text("Fantasy Services")
                } footer: {
                    Text("Connect your ESPN and Sleeper accounts to access leagues and drafts.")
                }
                
                // MARK: -> App Settings
                Section {
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
                    
                    // 🎯 MODERN SPORTS APP DESIGN TOGGLE
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
                    
                    // 🔥 NEW: Bar-style layout toggle for Mission Control
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
                    
                    // 💊 RX: Lineup Optimization Threshold
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
                } header: {
                    Text("App Settings")
                } footer: {
                    Text("Configure app behavior and data refresh settings.")
                }
                
                // MARK: -> Developer Settings
                Section {
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
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Advanced settings for debugging and development.")
                }
                
                // MARK: -> Data Management
                Section {
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
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("⚠️ Use with caution. These actions cannot be undone.")
                }
                
                // MARK: -> About Section
                Section {
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
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mission Control") {
                        // 🔥 NEW: Navigate back to Mission Control using existing notification system
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.gpGreen)
                }
            }
            .onAppear {
                // 🔥 FIX: Refresh status when returning from setup views
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
    @State private var nflWeekService = NFLWeekService.shared
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

// MARK: -> Preview

#Preview {
    AppSettingsView()
}