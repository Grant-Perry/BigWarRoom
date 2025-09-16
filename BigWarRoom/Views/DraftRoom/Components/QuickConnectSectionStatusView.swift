//
//  QuickConnectSectionStatusView.swift
//  BigWarRoom
//
//  Connection status component for QuickConnectSection - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuickConnectSectionStatusView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                
                Text("Connected.")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            // Service logos - only show logos for services that actually have leagues
            HStack(spacing: 25) {
                // Show Sleeper logo only if we have Sleeper leagues
                if viewModel.allAvailableDrafts.contains(where: { $0.source == .sleeper }) {
                    AppConstants.sleeperLogo
                        .frame(width: 20, height: 20)
                        .shadow(color: .green.opacity(0.3), radius: 2)
                }
                
                // Show ESPN logo only if we have ESPN leagues
                if viewModel.connectionStatus == .connected && viewModel.allAvailableDrafts.contains(where: { $0.source == .espn }) {
                    AppConstants.espnLogo
                        .frame(width: 20, height: 20)
                        .shadow(color: .green.opacity(0.3), radius: 2)
                }
            }
        }
    }
}