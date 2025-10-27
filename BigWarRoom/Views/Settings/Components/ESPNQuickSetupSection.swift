//
//  ESPNQuickSetupSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Quick setup section with default credentials
struct ESPNQuickSetupSection: View {
    @Bindable var viewModel: ESPNSetupViewModel
    
    var body: some View {
        Section {
            Button("Use Default Credentials (Gp's Account)") {
                viewModel.fillDefaultCredentials()
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.blue)
        } header: {
            Text("Quick Setup")
        } footer: {
            Text("This will auto-fill with the default ESPN credentials. You can modify them or use your own.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}