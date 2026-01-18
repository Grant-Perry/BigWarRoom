//
//  SettingsView.swift
//  BigWarRoom
//
//  RENAMED: This file contains OnBoardingView - keeping for new user onboarding
//  The actual SettingsView will be in a separate file
//

import SwiftUI

struct OnBoardingView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(NFLWeekService.self) private var nflWeekService
    
    init() {
        // We'll need to fix this - can't access @Environment in init
        // For now, use a placeholder and update in onAppear
        _viewModel = State(wrappedValue: SettingsViewModel(nflWeekService: NFLWeekService(apiClient: SleeperAPIClient())))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Text("Welcome to BigWarRoom")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Connect your fantasy services to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Service Setup Cards
                    VStack(spacing: 16) {
                        // ESPN Card
                        ServiceSetupCard(
                            logo: AppConstants.espnLogo,
                            title: "ESPN Fantasy",
                            subtitle: viewModel.espnHasCredentials ? 
                                "✅ Connected" : 
                                "⚠️ Manual setup required",
                            description: viewModel.espnHasCredentials ? 
                                "Ready to use" :
                                "Requires cookies & league IDs",
                            isConnected: viewModel.espnHasCredentials,
                            accentColor: .orange,
                            action: {
                                viewModel.showESPNSetup()
                            }
                        )
                        
                        // Sleeper Card
                        ServiceSetupCard(
                            logo: AppConstants.sleeperLogo,
                            title: "Sleeper Fantasy",
                            subtitle: viewModel.sleeperHasCredentials ? 
                                "✅ Connected" : 
                                "⭐ Recommended (easier)",
                            description: viewModel.sleeperHasCredentials ? 
                                "Ready to use" :
                                "Just username or user ID",
                            isConnected: viewModel.sleeperHasCredentials,
                            accentColor: .blue,
                            action: {
                                viewModel.showSleeperSetup()
                            }
                        )
                    }
                    
                    // Quick Actions
                    if viewModel.espnHasCredentials || viewModel.sleeperHasCredentials {
                        VStack(spacing: 12) {
                            Divider()
                            
                            Text("Quick Actions")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 8) {
                                Button("Clear All Credentials") {
                                    viewModel.requestClearAllServices()
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                
                                Button("Clear Cache Only") {
                                    viewModel.requestClearAllCache()
                                }
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                                
                                Button("Clear All Persisted Data") {
                                    viewModel.requestClearAllPersistedData()
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Footer
                    VStack(spacing: 8) {
                        Button("About BigWarRoom") {
                            viewModel.showAbout()
                        }
                        .foregroundColor(.blue)
                        
                        Text("Version \(AppConstants.getVersion())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Account for tab bar
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showingESPNSetup) {
                ESPNSetupView()
            }
            .sheet(isPresented: $viewModel.showingSleeperSetup) {
                SleeperSetupView()
            }
            .sheet(isPresented: $viewModel.showingAbout) {
                AboutView()
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
        .onAppear {
            // Re-initialize with proper nflWeekService from environment
            viewModel = SettingsViewModel(nflWeekService: nflWeekService)
        }
    }
}

// MARK: - Service Setup Card

struct ServiceSetupCard<Logo: View>: View {
    let logo: Logo
    let title: String
    let subtitle: String
    let description: String
    let isConnected: Bool
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    logo
                        .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(isConnected ? .green : .orange)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !isConnected {
                    HStack {
                        Text("Tap to configure")
                            .font(.caption)
                            .foregroundColor(accentColor)
                        
                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isConnected ? Color.green.opacity(0.3) : accentColor.opacity(0.3),
                        lineWidth: isConnected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - About View (Simplified)

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("BigWarRoom")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your fantasy football draft companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Version \(AppConstants.getVersion())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "link", title: "Multi-Platform", description: "ESPN & Sleeper support")
                    FeatureRow(icon: "brain.head.profile", title: "AI Suggestions", description: "Smart pick recommendations")
                    FeatureRow(icon: "sportscourt", title: "Live Tracking", description: "Real-time draft board")
                }
                
                Spacer()
                
                Text("Made with ❤️ for fantasy football")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Row (Simplified)

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}