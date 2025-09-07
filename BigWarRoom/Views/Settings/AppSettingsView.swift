//
//  AppSettingsView.swift
//  BigWarRoom
//
//  Main settings and configuration view for existing users
//

import SwiftUI

struct AppSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingConnectionSuccess = false
    @State private var connectionSuccessMessage = ""
    
    var body: some View {
        NavigationView {
            List {
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
    @ObservedObject private var nflWeekService = NFLWeekService.shared
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