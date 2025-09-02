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
    @State private var selectedYear: String = "2025"
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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
            autoConnectOnAppear()
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
    
    private func autoConnectOnAppear() {
        // Auto-connect to default services on page load
        if viewModel.connectionStatus != .connected {
            Task {
                // Connect to both Sleeper and ESPN with default user using selected season
                await viewModel.connectWithUsernameOrID(AppConstants.GpSleeperID, season: selectedYear)
            }
        }
    }
}