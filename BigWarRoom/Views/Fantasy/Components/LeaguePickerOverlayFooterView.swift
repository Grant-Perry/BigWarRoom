//
//  LeaguePickerOverlayFooterView.swift
//  BigWarRoom
//
//  Footer component for LeaguePickerOverlay
//

import SwiftUI

/// Footer view for league picker overlay
struct LeaguePickerOverlayFooterView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Tap any league to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}