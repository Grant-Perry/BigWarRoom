//
//  QuickConnectSectionYearPickerView.swift
//  BigWarRoom
//
//  Year picker component for QuickConnectSection - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuickConnectSectionYearPickerView: View {
    @Bindable var viewModel: DraftRoomViewModel
    @Binding var selectedYear: String
    @Binding var customSleeperInput: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Season Year")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Picker("Season Year", selection: $selectedYear) {
                ForEach(AppConstants.availableYears, id: \.self) { year in
                    Text(year).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedYear) { _, newYear in
                AppConstants.ESPNLeagueYear = newYear
                
                if viewModel.connectionStatus == .connected {
                    Task {
                        await viewModel.connectWithUsernameOrID(customSleeperInput, season: newYear)
                    }
                }
            }
        }
    }
}