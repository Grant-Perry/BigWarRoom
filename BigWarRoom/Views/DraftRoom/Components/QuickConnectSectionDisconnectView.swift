//
//  QuickConnectSectionDisconnectView.swift
//  BigWarRoom
//
//  Disconnect button component for QuickConnectSection - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuickConnectSectionDisconnectView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        Button("Disconnect All Services") {
            viewModel.disconnectFromLive()
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}