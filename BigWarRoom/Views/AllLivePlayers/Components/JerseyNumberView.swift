//
//  JerseyNumberView.swift
//  BigWarRoom
//
//  Large background jersey number display component - extracted from Active Roster cards
//

import SwiftUI

/// **Standalone Jersey Number View**
/// Displays a large, semi-transparent jersey number in the background like Active Roster cards
struct JerseyNumberView: View {
    let jerseyNumber: String
    let teamColor: Color
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    HStack(alignment: .top, spacing: 2) {
                        // 🔥 FIXED: Small superscript # symbol with stronger contrast
                        Text("#")
						  .font(.system(size: 33, weight: .thin))
                            .italic()
                            .foregroundColor(teamColor)
                            .opacity(0.75)
                            .shadow(color: .black, radius: 4, x: 2, y: 2) // 🔥 STRONGER shadow
                            .overlay(
                                Text("#")
                                    .font(.system(size: 33, weight: .thin))
                                    .italic()
                                    .foregroundColor(.black)
                                    .opacity(0.3)
                                    .blur(radius: 1)
                            ) // 🔥 BLACK outline for contrast
							.offset(x: 8, y: 20) // Position it higher like a superscript

                        // Large jersey number with stronger contrast
                        Text(jerseyNumber)
                            .font(.system(size: 90, weight: .black))
                            .italic()
                            .foregroundColor(teamColor)
                            .opacity(1.0) // 🔥 FULL OPACITY: Completely opaque
                            .shadow(color: .black, radius: 6, x: 3, y: 3) // 🔥 MUCH stronger shadow
                            .overlay(
                                Text(jerseyNumber)
                                    .font(.system(size: 90, weight: .black))
                                    .italic()
                                    .foregroundColor(.black)
                                    .opacity(0.4)
                                    .blur(radius: 2)
                            ) // 🔥 BLACK outline/glow for strong contrast
                    }
                }
            }
            .padding(.trailing, 8)
			.offset(y: 10)
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        JerseyNumberView(
            jerseyNumber: "17",
            teamColor: .blue
        )
        .frame(width: 200, height: 100)
        .background(Color.gray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}