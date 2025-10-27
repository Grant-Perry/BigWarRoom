//
//  ESPNCredentialsSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Credentials section with SWID and ESPN_S2 fields
struct ESPNCredentialsSection: View {
    @Bindable var viewModel: ESPNSetupViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("SWID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Your ESPN SWID (e.g., {ABC-123-DEF})", text: $viewModel.swid)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("ESPN_S2 Cookie")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Your ESPN_S2 authentication cookie", text: $viewModel.espnS2, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            HStack {
                Button("Save Credentials") {
                    viewModel.saveCredentials()
                }
                .disabled(!viewModel.canSaveCredentials)
                
                Spacer()
                
                if viewModel.hasValidCredentials {
                    Button("Validate") {
                        viewModel.validateCredentials()
                    }
                    .disabled(viewModel.isValidating)
                }
            }
        } header: {
            Text("ESPN Authentication")
        } footer: {
            Text("Your ESPN credentials are stored securely in Keychain and never shared.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}