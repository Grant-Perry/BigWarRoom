//
//  ConnectionServiceCardView.swift
//  BigWarRoom
//
//  Service connection card component - CLEAN ARCHITECTURE
//

import SwiftUI

struct ConnectionServiceCardView<Logo: View>: View {
    let logo: Logo
    let title: String
    let subtitle: String
    let isConnected: Bool
    let accentColor: Color
    let showUseDefault: Bool
    let action: () -> Void
    let useDefaultAction: (() -> Void)?
    
    init(logo: Logo, title: String, subtitle: String, isConnected: Bool, accentColor: Color, showUseDefault: Bool = false, action: @escaping () -> Void, useDefaultAction: (() -> Void)? = nil) {
        self.logo = logo
        self.title = title
        self.subtitle = subtitle
        self.isConnected = isConnected
        self.accentColor = accentColor
        self.showUseDefault = showUseDefault
        self.action = action
        self.useDefaultAction = useDefaultAction
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main connection card
            Button(action: action) {
                HStack(spacing: 12) {
                    logo
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(isConnected ? .green : accentColor)
                    }
                    
                    Spacer()
                    
                    if !isConnected {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(accentColor)
                            .font(.title3)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .disabled(isConnected)
            
            // Use Default button (only if not connected and showUseDefault is true)
            if !isConnected && showUseDefault && useDefaultAction != nil {
                Divider()
                
                Button("Use Default (Gp's Account)") {
                    useDefaultAction?()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isConnected ? Color.green.opacity(0.3) : accentColor.opacity(0.2),
                    lineWidth: isConnected ? 2 : 1
                )
        )
    }
}