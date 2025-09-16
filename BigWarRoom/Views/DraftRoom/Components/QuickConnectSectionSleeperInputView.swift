//
//  QuickConnectSectionSleeperInputView.swift
//  BigWarRoom
//
//  Sleeper input component for QuickConnectSection - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuickConnectSectionSleeperInputView: View {
    @Binding var customSleeperInput: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleeper Username/ID")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                TextField("e.g. 'gpick' or user ID", text: $customSleeperInput)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                
                Button("Use Default") {
                    customSleeperInput = AppConstants.SleeperUser
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
}