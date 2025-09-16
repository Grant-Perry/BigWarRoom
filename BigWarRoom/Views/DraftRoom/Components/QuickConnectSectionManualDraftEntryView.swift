//
//  QuickConnectSectionManualDraftEntryView.swift
//  BigWarRoom
//
//  Manual draft entry component for QuickConnectSection - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuickConnectSectionManualDraftEntryView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Binding var manualDraftID: String
    @Binding var isConnectingToDraft: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Manual Draft ID")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 8) {
                TextField("Enter any draft ID", text: $manualDraftID)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .disabled(isConnectingToDraft)
                
                Button(isConnectingToDraft ? "..." : "Connect") {
                    Task {
                        isConnectingToDraft = true
                        await viewModel.connectToManualDraft(draftID: manualDraftID)
                        isConnectingToDraft = false
                    }
                }
                .font(.callout)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(manualDraftID.isEmpty || isConnectingToDraft)
            }
        }
        .padding(.top, 8) // Add some spacing from the sections above
    }
}