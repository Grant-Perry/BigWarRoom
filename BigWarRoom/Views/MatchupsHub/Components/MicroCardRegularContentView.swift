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
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(scoreColor.opacity(0.6))
                    .overlay(
                        Text(String(managerName.prefix(2)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .frame(width: 36, height: 36)
            }
            
            // Manager name
            Text(managerName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Manager record
            Text("Record: TEST")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.red)
                .lineLimit(1)
            
            if let record = record {
                Text("Record: \(record)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
                    .lineLimit(1)
            } else {
                Text("Record: nil")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.red)
                    .lineLimit(1)
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