//
//  CredentialsSectionView.swift
//  BigWarRoom
//
//  Credentials input section component for Sleeper authentication
//

import SwiftUI

/// Component handling Sleeper credentials input and validation
struct CredentialsSectionView: View {
    @Binding var username: String
    @Binding var userID: String  // Keep binding for compatibility but hide the UI
    @Binding var selectedSeason: String
    let hasValidCredentials: Bool
    let canSaveCredentials: Bool
    let isValidating: Bool
    let onSaveCredentials: () -> Void
    let onValidateCredentials: () -> Void
    
    var body: some View {
        Section {
            // Username input section - ONLY field needed
            UsernameInputSection(username: $username, onConnectTapped: onSaveCredentials, canConnect: canSaveCredentials)
            
            // Season picker section
            SeasonPickerSection(selectedSeason: $selectedSeason)
            
            // Action buttons (keep existing for backward compatibility)
            CredentialsActionsRow(
                hasValidCredentials: hasValidCredentials,
                canSaveCredentials: canSaveCredentials,
                isValidating: isValidating,
                onSaveCredentials: onSaveCredentials,
                onValidateCredentials: onValidateCredentials
            )
        } header: {
            Text("Sleeper Authentication")
        } footer: {
            Text("Enter your Sleeper username. The app will automatically discover all your leagues!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Components

/// Username input component with Connect button
private struct UsernameInputSection: View {
    @Binding var username: String
    let onConnectTapped: () -> Void
    let canConnect: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleeper Username")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                TextField("Enter your Sleeper username (e.g., costanzaphoto)", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                // 🔥 NEW: Connect button right under username field
                HStack {
                    Button("Connect") {
                        onConnectTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConnect)
                    
                    Spacer()
                    
                    if !canConnect {
                        Text("Enter username to connect")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

/// Season picker component
private struct SeasonPickerSection: View {
    @Binding var selectedSeason: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Season")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Season", selection: $selectedSeason) {
                Text("2024").tag("2024")
                Text("2025").tag("2025")
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Actions row with save and validate buttons
private struct CredentialsActionsRow: View {
    let hasValidCredentials: Bool
    let canSaveCredentials: Bool
    let isValidating: Bool
    let onSaveCredentials: () -> Void
    let onValidateCredentials: () -> Void
    
    var body: some View {
        HStack {
            Button("Save Credentials") {
                onSaveCredentials()
            }
            .disabled(!canSaveCredentials)
            
            Spacer()
            
            if hasValidCredentials {
                Button("Validate") {
                    onValidateCredentials()
                }
                .disabled(isValidating)
            }
        }
    }
}