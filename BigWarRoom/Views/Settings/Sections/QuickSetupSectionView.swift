//
//  QuickSetupSectionView.swift
//  BigWarRoom
//
//  Quick setup section component for default credentials
//

import SwiftUI

/// Component providing quick setup with default credentials
struct QuickSetupSectionView: View {
    let onDefaultCredentialsTapped: () -> Void
    
    var body: some View {
        Section {
            Button("Use Default Credentials (Gp's Account)") {
                onDefaultCredentialsTapped()
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.blue)
        } header: {
            Text("Quick Setup")
        } footer: {
            Text("This will auto-fill with the default Sleeper credentials. You can modify them or use your own.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}