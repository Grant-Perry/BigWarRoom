//
//  ESPNAdvancedSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Advanced section with reset options
struct ESPNAdvancedSection: View {
    @ObservedObject var viewModel: ESPNSetupViewModel
    
    var body: some View {
        Section {
            Button("Clear ESPN Credentials") {
                viewModel.requestClearCredentialsOnly()
            }
            .foregroundColor(.orange)
            
            Button("Clear ESPN League IDs") {
                viewModel.requestClearLeagueIDsOnly()
            }
            .foregroundColor(.orange)
            
            Divider()
            
            Button("Clear All ESPN Data") {
                viewModel.requestClearCredentials()
            }
            .foregroundColor(.red)
            .fontWeight(.bold)
        } header: {
            Text("Reset ESPN Data")
        } footer: {
            Text("Clear specific ESPN data or all ESPN credentials and league IDs.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}