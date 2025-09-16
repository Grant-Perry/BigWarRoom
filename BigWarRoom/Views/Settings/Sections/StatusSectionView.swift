//
//  StatusSectionView.swift
//  BigWarRoom
//
//  Status section component for Sleeper setup displaying connection status and continue button
//

import SwiftUI

/// Component displaying Sleeper connection status with continue button when setup is complete
struct StatusSectionView: View {
    let hasValidCredentials: Bool
    let isSetupComplete: Bool
    let onInstructionsTapped: () -> Void
    let onContinueTapped: () -> Void
    
    var body: some View {
        Section {
            // Connection status header
            ConnectionStatusHeader(
                hasValidCredentials: hasValidCredentials,
                onInstructionsTapped: onInstructionsTapped
            )
            
            // Setup complete section with continue button
            if isSetupComplete {
                SetupCompleteSection(onContinueTapped: onContinueTapped)
            }
            
            // Help hint for incomplete setup
            if !hasValidCredentials {
                SetupHelpHint()
            }
        } header: {
            Text("Status")
        }
    }
}

// MARK: - Supporting Components

/// Header showing connection status with instructions button
private struct ConnectionStatusHeader: View {
    let hasValidCredentials: Bool
    let onInstructionsTapped: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: hasValidCredentials ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(hasValidCredentials ? .green : .orange)
            
            Text(hasValidCredentials ? "Sleeper Connected" : "Sleeper Not Configured")
                .font(.headline)
            
            Spacer()
            
            Button("Instructions") {
                onInstructionsTapped()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }
}

/// Setup complete section with continue button
private struct SetupCompleteSection: View {
    let onContinueTapped: () -> Void
    
    var body: some View {
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
                onContinueTapped()
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
}

/// Help hint for incomplete setup
private struct SetupHelpHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("💡 Sleeper is much easier! Just need your username or user ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}