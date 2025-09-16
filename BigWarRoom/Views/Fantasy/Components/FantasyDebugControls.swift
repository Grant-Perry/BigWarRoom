//
//  FantasyDebugControls.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Debug controls for Fantasy view (only shown in debug mode)
struct FantasyDebugControls: View {
    @Binding var forceChoppedMode: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // DEBUG: ESPN Test Button (only in debug mode)
            if AppConstants.debug {
                NavigationLink(destination: ESPNFantasyTestView()) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.red)
                        
                        Text("🔥 ESPN Fantasy Test (SleepThis Integration)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
                
                // FORCE CHOPPED MODE BUTTON
                Button(action: {
                    forceChoppedMode.toggle()
                }) {
                    HStack {
                        Text("💀")
                        Text(forceChoppedMode ? "DISABLE CHOPPED MODE" : "🔥 FORCE CHOPPED BATTLE ROYALE 🔥")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                        Text("💀")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(forceChoppedMode ? 0.2 : 0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
}