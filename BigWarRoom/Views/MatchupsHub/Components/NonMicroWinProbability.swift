//
//  NonMicroWinProbability.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Win probability display for non-micro cards
struct NonMicroWinProbability: View {
    let winProb: Double
    
    var body: some View {
        VStack(spacing: 4) {
            // Probability text
            HStack {
                Text("\(Int(winProb * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Spacer()
                
                Text("\(Int((1 - winProb) * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Probability bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gpGreen)
                        .frame(width: geometry.size.width * winProb, height: 4)
                        .animation(.easeInOut(duration: 1.0), value: winProb)
                }
            }
            .frame(height: 4)
        }
    }
}