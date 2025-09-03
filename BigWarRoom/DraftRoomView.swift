//
//  DraftRoomView.swift
//  BigWarRoom
//
//  Main Draft Room UI - Clean MVVM Architecture
//

import SwiftUI

struct DraftRoomView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Binding var selectedTab: Int
    @State private var selectedYear: String = AppConstants.ESPNLeagueYear
    @StateObject private var espnCredentials = ESPNCredentialsManager.shared
    @StateObject private var sleeperCredentials = SleeperCredentialsManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Service Setup Notices (if not configured)
                if !espnCredentials.hasValidCredentials || !sleeperCredentials.hasValidCredentials {
                    ServiceSetupNotices(
                        selectedTab: $selectedTab,
                        showESPN: !espnCredentials.hasValidCredentials,
                        showSleeper: !sleeperCredentials.hasValidCredentials
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                
                // STEP 1: Connection Section
                QuickConnectSection(
                    viewModel: viewModel, 
                    selectedYear: $selectedYear
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // STEP 2: Draft Selection (Show if connected)
                if viewModel.connectionStatus == .connected {
                    DraftSelectionSection(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                
                // STEP 3: Active Draft Status (Show if draft selected)
                if viewModel.selectedDraft != nil || viewModel.isConnectedToManualDraft {
                    ActiveDraftSection(viewModel: viewModel)
                        .padding(.horizontal) 
                        .padding(.bottom, 20)
                }
                
                // STEP 4: Draft Actions & Quick Tools
                if viewModel.selectedDraft != nil || viewModel.isConnectedToManualDraft {
                    DraftQuickActionsSection(
                        viewModel: viewModel,
                        selectedTab: $selectedTab
                    )
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("War Room")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Only auto-connect if user already has configured credentials
            autoConnectIfConfigured()
        }
        .alert("YOUR TURN!", isPresented: $viewModel.showingPickAlert) {
            Button("Got It!") { viewModel.dismissPickAlert() }
            Button("View Suggestions") { viewModel.dismissPickAlert() }
        } message: {
            Text(viewModel.pickAlertMessage)
        }
        .alert("Pick Confirmed", isPresented: $viewModel.showingConfirmationAlert) {
            Button("Nice!") { viewModel.dismissConfirmationAlert() }
        } message: {
            Text(viewModel.confirmationAlertMessage)
        }
        .sheet(isPresented: $viewModel.showingESPNPickPrompt) {
            ESPNDraftPickSelectionSheet(
                leagueName: viewModel.pendingESPNLeagueWrapper?.league.name ?? "ESPN League",
                maxTeams: viewModel.maxTeamsInDraft,
                selectedPick: $viewModel.selectedESPNDraftPosition,
                onConfirm: { pick in
                    Task { await viewModel.setESPNDraftPosition(pick) }
                },
                onCancel: { viewModel.cancelESPNPositionSelection() }
            )
        }
    }
    
    // MARK: - Helper Methods (Minimal View Logic Only)
    
    private func autoConnectIfConfigured() {
        // Only auto-connect if user has already set up credentials
        // Don't force Gp's default settings - respect the onboarding flow
        if viewModel.connectionStatus != .connected {
            if espnCredentials.hasValidCredentials || sleeperCredentials.hasValidCredentials {
                Task {
                    // Connect using stored credentials, not hardcoded defaults
                    if let sleeperID = sleeperCredentials.getUserIdentifier() {
                        await viewModel.connectWithUsernameOrID(sleeperID, season: selectedYear)
                    }
                }
            }
        }
    }
}

// MARK: - Service Setup Notices Component

struct ServiceSetupNotices: View {
    @Binding var selectedTab: Int
    let showESPN: Bool
    let showSleeper: Bool
    @StateObject private var espnCredentials = ESPNCredentialsManager.shared
    @StateObject private var sleeperCredentials = SleeperCredentialsManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            if showESPN {
                ESPNSetupNoticeCard(selectedTab: $selectedTab)
            }
            
            if showSleeper {
                SleeperSetupNoticeCard(selectedTab: $selectedTab)
            }
        }
    }
}

struct ESPNSetupNoticeCard: View {
    @Binding var selectedTab: Int
    @StateObject private var credentialsManager = ESPNCredentialsManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                AppConstants.espnLogo
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESPN Not Connected")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Set up ESPN credentials to access your leagues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Quick Setup") {
                        quickSetupESPN()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Custom Setup") {
                        selectedTab = 6 // Navigate to OnBoarding tab
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private func quickSetupESPN() {
        // Don't auto-fill with Gp's credentials - let users set their own
        // This was forcing Gp's settings on everyone
        print("🚀 Navigate to ESPN setup for user to enter their own credentials")
        selectedTab = 6 // Navigate to settings for proper setup
    }
}

struct SleeperSetupNoticeCard: View {
    @Binding var selectedTab: Int
    @StateObject private var credentialsManager = SleeperCredentialsManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                AppConstants.sleeperLogo
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleeper Not Connected")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Set up Sleeper username to access your leagues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Quick Setup") {
                        quickSetupSleeper()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Custom Setup") {
                        selectedTab = 6 // Navigate to Settings tab
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private func quickSetupSleeper() {
        // Don't auto-fill with Gp's credentials - let users set their own  
        // This was forcing Gp's settings on everyone
        print("🚀 Navigate to Sleeper setup for user to enter their own credentials")
        selectedTab = 6 // Navigate to settings for proper setup
    }
}