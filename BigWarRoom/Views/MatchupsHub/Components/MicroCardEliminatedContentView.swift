//
//  MicroCardEliminatedContentView.swift
//  BigWarRoom
//
//  Eliminated content component for MicroCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct MicroCardEliminatedContentView: View {
    let managerName: String
    let eliminationWeek: Int?
    let eliminatedPulse: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            // Avatar replacement - skull icon
            Circle()
                .fill(Color.red.opacity(0.3))
                .overlay(
                    Text("☠️")
                        .font(.system(size: 18))
                        .scaleEffect(eliminatedPulse ? 1.1 : 1.0)
                )
                .frame(width: 36, height: 36)
            
            // Manager name replacement - ELIMINATED
            Text("ELIMINATED")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white)
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Score/Percentage replacement - Week info
            VStack(spacing: 4) {
                if let week = eliminationWeek {
                    Text("Week \(week)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.red)
                }
                
                // Manager name
                Text(managerName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}