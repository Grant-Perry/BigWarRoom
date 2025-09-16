//
//  MissionControlHeaderView.swift
//  BigWarRoom
//
//  Mission Control hero header component
//

import SwiftUI

/// Hero header component for Mission Control with title and branding
struct MissionControlHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Mission Control title section
            MissionControlTitleSection()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Supporting Components

/// Mission Control title with icons and subtitle
private struct MissionControlTitleSection: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("MISSION CONTROL")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .gpGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Image(systemName: "rocket")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gpGreen)
            }
            
            Text("Fantasy Football Command Center")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}