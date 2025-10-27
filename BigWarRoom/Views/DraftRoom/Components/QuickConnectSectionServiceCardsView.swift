//
//  QuickConnectSectionServiceCardsView.swift
//  BigWarRoom
//
//  Service cards component for QuickConnectSection - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuickConnectSectionServiceCardsView: View {
    @Bindable var viewModel: DraftRoomViewModel
    @Binding var selectedTab: Int
    @Binding var selectedYear: String
    @Binding var customSleeperInput: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Sleeper Card - + button opens credential entry
            ConnectionServiceCardView(
                logo: AppConstants.sleeperLogo,
                title: "Sleeper Fantasy",
                subtitle: isSleeperConnected ? "✅ Connected" : "Connect to Sleeper",
                isConnected: isSleeperConnected,
                accentColor: .blue,
                showUseDefault: true,
                action: {
                    // + button action: Navigate to Sleeper setup in Settings
                    selectedTab = 7 // Navigate to Settings tab (now index 7)
                },
                useDefaultAction: {
                    // Use Default button: Auto-connect with default credentials
                    customSleeperInput = AppConstants.SleeperUser
                    Task {
                        await viewModel.connectWithUsernameOrID(AppConstants.SleeperUser, season: selectedYear)
                    }
                }
            )
            
            // ESPN Card - + button opens credential entry
            ConnectionServiceCardView(
                logo: AppConstants.espnLogo,
                title: "ESPN Fantasy", 
                subtitle: isESPNConnected ? "✅ Connected" : "Connect to ESPN",
                isConnected: isESPNConnected,
                accentColor: .orange,
                showUseDefault: true,
                action: {
                    // + button action: Navigate to ESPN setup in Settings
                    selectedTab = 7 // Navigate to Settings tab (now index 7)
                },
                useDefaultAction: {
                    // Use Default button: Auto-connect with default ESPN credentials
                    Task {
                        // Fill default ESPN credentials first
                        ESPNCredentialsManager.shared.saveCredentials(
                            swid: AppConstants.SWID,
                            espnS2: AppConstants.ESPN_S2,
                            leagueIDs: AppConstants.ESPNLeagueID
                        )
                        
                        AppConstants.ESPNLeagueYear = selectedYear
                        await viewModel.connectToESPNOnly()
                    }
                }
            )
        }
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var isSleeperConnected: Bool {
        // Check if we actually have Sleeper leagues loaded (not just general connection status)
        return viewModel.allAvailableDrafts.contains(where: { $0.source == .sleeper })
    }
    
    private var isESPNConnected: Bool {
        viewModel.allAvailableDrafts.contains(where: { $0.source == .espn })
    }
}