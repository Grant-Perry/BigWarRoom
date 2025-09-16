//
//  ValidationOverlayView.swift
//  BigWarRoom
//
//  Overlay component for showing validation progress
//

import SwiftUI

/// Overlay component for displaying validation or loading states
struct ValidationOverlayView: View {
    let isValidating: Bool
    let message: String
    
    var body: some View {
        if isValidating {
            ProgressView(message)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
        }
    }
}