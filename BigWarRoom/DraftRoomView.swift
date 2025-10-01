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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Connection section stays pinned at top (outside ScrollView)
                VStack(spacing: 16) {
                    // Service Setup Notices (if not configured)
                    if !espnCredentials.hasValidCredentials || !sleeperCredentials.hasValidCredentials {
                        ServiceSetupNotices(
                            selectedTab: $selectedTab,
                            showESPN: !espnCredentials.hasValidCredentials,
                            showSleeper: !sleeperCredentials.hasValidCredentials
                        )
                        .padding(.horizontal)
                    }
                    
                    // STEP 1: Connection Section - STAYS AT TOP
                    QuickConnectSection(
                        viewModel: viewModel, 
                        selectedYear: $selectedYear,
                        selectedTab: $selectedTab
                    )
                    .padding(.horizontal)
                }
                .background(Color(.systemGroupedBackground))
                
                // Scrollable content below the connection section
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // STEP 2: Draft Selection (Show if connected) - Enhanced to fill more space
                        if viewModel.connectionStatus == .connected {
                            DraftSelectionSection(viewModel: viewModel, selectedTab: $selectedTab)
                                .frame(minHeight: max(300, geometry.size.height * 0.4))
                                .padding(.horizontal)
                                .padding(.top, 16)
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
                            .padding(.bottom, 100) // Extra bottom padding for better scrolling
                        }
                        
                        // Spacer to push content up and fill remaining space
                        if viewModel.connectionStatus == .connected && !viewModel.allAvailableDrafts.isEmpty {
                            Spacer(minLength: 50)
                        }
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToFantasy"))) { _ in
            // Auto-navigate to Fantasy tab when position is confirmed (updated index)
            selectedTab = 7 // Fantasy tab is now index 7
            NSLog("🏈 Auto-navigated to Fantasy tab after confirming position")
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
            ESPNDraftPickSelectionSheet.forDraft(
                leagueName: viewModel.pendingESPNLeagueWrapper?.league.name ?? "ESPN League",
                maxTeams: viewModel.maxTeamsInDraft,
                selectedPosition: $viewModel.selectedESPNDraftPosition,
                onConfirm: { pick in
                    Task { await viewModel.setESPNDraftPosition(pick) }
                },
                onCancel: { viewModel.cancelESPNPositionSelection() }
            )
        }
    }
    
    // MARK: - Helper Methods (Minimal View Logic Only)

    private func autoConnectIfConfigured() {
        // Don't auto-connect if we already have leagues loaded (either service)
        if !viewModel.allAvailableDrafts.isEmpty { return }

        let hasESPNCredentials = espnCredentials.hasValidCredentials
        let hasSleeperCredentials = sleeperCredentials.hasValidCredentials

        Task {
            await connectToAllAvailableServices()
        }
    }

    /// Connects to all available fantasy services (ESPN & Sleeper), merging results.
    /// Always runs both connections in parallel if creds exist, never prioritizes one.
    private func connectToAllAvailableServices() async {
        let hasESPNCredentials = espnCredentials.hasValidCredentials
        let hasSleeperCredentials = sleeperCredentials.hasValidCredentials

        await withTaskGroup(of: Void.self) { group in
            if hasESPNCredentials {
                group.addTask {
                    await viewModel.connectToESPNOnly()
                }
            }
            if hasSleeperCredentials {
                if let sleeperID = sleeperCredentials.getUserIdentifier() {
                    group.addTask {
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
                        selectedTab = 7 // Navigate to Settings tab (now index 7)
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
        selectedTab = 7 // Navigate to settings for proper setup
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
                        selectedTab = 7 // Navigate to Settings tab (now index 7)
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
        selectedTab = 7 // Navigate to settings for proper setup
    }
}