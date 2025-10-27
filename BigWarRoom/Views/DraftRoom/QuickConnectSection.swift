import SwiftUI

struct QuickConnectSection: View {
    @Bindable var viewModel: DraftRoomViewModel
    @Binding var selectedYear: String
    @Binding var selectedTab: Int // Add this for navigation
    @State private var customSleeperInput: String = ""
    @State private var showConnectionSection = false
    @State private var manualDraftID: String = ""
    @State private var isConnectingToDraft = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header - use component
            QuickConnectSectionHeaderView(
                viewModel: viewModel,
                selectedYear: $selectedYear,
                showConnectionSection: $showConnectionSection
            )
            
            // Service Cards (like OnBoarding)
            if showConnectionSection || viewModel.connectionStatus != .connected {
                VStack(spacing: 12) {
                    // Year picker - use component
                    QuickConnectSectionYearPickerView(
                        viewModel: viewModel,
                        selectedYear: $selectedYear,
                        customSleeperInput: $customSleeperInput
                    )
                    
                    // Service connection cards - use component
                    QuickConnectSectionServiceCardsView(
                        viewModel: viewModel,
                        selectedTab: $selectedTab,
                        selectedYear: $selectedYear,
                        customSleeperInput: $customSleeperInput
                    )
                    
                    // Sleeper input (only if not connected) - use component
                    if viewModel.connectionStatus != .connected {
                        QuickConnectSectionSleeperInputView(
                            customSleeperInput: $customSleeperInput
                        )
                    }
                    
                    // Disconnect button (only if connected) - use component
                    if viewModel.connectionStatus == .connected {
                        QuickConnectSectionDisconnectView(
                            viewModel: viewModel
                        )
                    }
                    
                    // Manual draft entry - use component
                    QuickConnectSectionManualDraftEntryView(
                        viewModel: viewModel,
                        manualDraftID: $manualDraftID,
                        isConnectingToDraft: $isConnectingToDraft
                    )
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.6), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .onAppear {
            // customSleeperInput = AppConstants.GpSleeperID
        }
    }
    
    // MARK: - Helper Methods (kept for any future use)
    
    private func getSleeperCredentialOrPrompt() -> String {
        // Check if user has saved Sleeper credentials
        let sleeperManager = SleeperCredentialsManager.shared
        if let identifier = sleeperManager.getUserIdentifier() {
            customSleeperInput = identifier
            return identifier
        }
        
        // If no saved credentials, use default username
        return AppConstants.SleeperUser
    }
    
}