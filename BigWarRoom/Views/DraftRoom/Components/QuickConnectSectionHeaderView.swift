//
//  QuickConnectSectionHeaderView.swift
//  BigWarRoom
//
//  Connection header component for QuickConnectSection - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuickConnectSectionHeaderView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Binding var selectedYear: String
    @Binding var showConnectionSection: Bool
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showConnectionSection.toggle()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connection")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if viewModel.connectionStatus == .connected {
                        QuickConnectSectionStatusView(viewModel: viewModel)
                    } else {
                        Text("Connect to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Text(selectedYear)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    
                    Image(systemName: showConnectionSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}