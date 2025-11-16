//
//  MicroCardRegularContentView.swift
//  BigWarRoom
//
//  Regular content component for MicroCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct MicroCardRegularContentView: View {
    let avatarURL: String?
    let managerName: String
    let score: String
    let scoreColor: Color
    let percentage: String
    let record: String?  // Add record parameter
    let onRXTap: (() -> Void)?  // 💊 RX button callback
    let isLineupOptimized: Bool  // 💊 RX: Optimization status
    
    var body: some View {
        VStack(spacing: 6) {
            // Avatar
            if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(scoreColor.opacity(0.6))
                        .overlay(
                            Text(String(managerName.prefix(2)).uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(scoreColor.opacity(0.6))
                    .overlay(
                        Text(String(managerName.prefix(2)).uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .frame(width: 24, height: 24)
            }
            
            // Manager name
            Text(managerName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Manager record (without "Record:" prefix)
            if let record = record {
                Text(record)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
                    .lineLimit(1)
            }
            
            // 💊 RX Button - above score/percentage
            if let onRXTap = onRXTap {
                MicroCardRXButton(onTap: onRXTap, isOptimized: isLineupOptimized)
                    .padding(.top, 2)
            }
            
            // Score + Percentage
            VStack(spacing: 4) {
                Text(score)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
                
                Text(percentage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - RX Button Component for Micro Cards
struct MicroCardRXButton: View {
    let onTap: () -> Void
    let isOptimized: Bool  // 💊 RX: Optimization status
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Image("LineupRX")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundColor(.white)
                Text("Rx")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(buttonBackgroundColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(buttonBackgroundColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 💊 RX: Dynamic button color based on optimization status
    private var buttonBackgroundColor: Color {
        return isOptimized ? .gpGreen : .gpRedPink
    }
}