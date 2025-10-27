//
//  ESPNStatusSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Status section with setup completion and continue button
struct ESPNStatusSection: View {
    @Bindable var viewModel: ESPNSetupViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        Section {
            HStack {
                Image(systemName: viewModel.hasValidCredentials ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(viewModel.hasValidCredentials ? .green : .orange)
                
                Text(viewModel.hasValidCredentials ? "ESPN Connected" : "ESPN Not Configured")
                    .font(.headline)
                
                Spacer()
                
                Button("Instructions") {
                    viewModel.showInstructions()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Setup Complete - Show Continue Button
            if viewModel.isSetupComplete {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Setup Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    
                    Button("Continue to Mission Control") {
                        // Navigate to Mission Control tab (0) instead of just dismissing
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
                        onDismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            if !viewModel.hasValidCredentials {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("💡 Tip: Use the 'ESPN Cookie Finder' Chrome extension for easiest setup!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Status")
        }
    }
}