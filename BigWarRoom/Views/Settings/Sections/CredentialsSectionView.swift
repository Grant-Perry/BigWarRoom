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
    @Binding var userID: String  
    @Binding var selectedSeason: String
    let hasValidCredentials: Bool
    let canSaveCredentials: Bool
    let isValidating: Bool
    let onSaveCredentials: () -> Void
    let onValidateCredentials: () -> Void
    
    var body: some View {
        Section {
            // Username input section
            UsernameInputSection(username: $username)
            
            // OR separator
            OrSeparator()
            
            // User ID input section
            UserIDInputSection(userID: $userID)
            
            // Season picker section
            SeasonPickerSection(selectedSeason: $selectedSeason)
            
            // Action buttons
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
            Text("Enter either your username OR user ID - not both. Sleeper automatically discovers all your leagues!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Components

/// Username input component
private struct UsernameInputSection: View {
    @Binding var username: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleeper Username")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Your Sleeper username (e.g., YourUsername)", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
    }
}

/// OR separator component
private struct OrSeparator: View {
    var body: some View {
        Text("OR")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// User ID input component
private struct UserIDInputSection: View {
    @Binding var userID: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleeper User ID")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Your Sleeper User ID (e.g., 123456789)", text: $userID)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.numberPad)
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