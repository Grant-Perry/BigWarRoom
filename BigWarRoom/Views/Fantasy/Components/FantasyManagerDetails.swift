//
//  FantasyManagerDetails.swift
//  BigWarRoom
//
//  Component for displaying fantasy manager information in matchup headers
//

import SwiftUI

/// Displays fantasy manager details including avatar, name, record, and score
struct FantasyManagerDetails: View {
    let managerName: String
    let managerRecord: String
    let score: Double
    let isWinning: Bool
    let avatarURL: URL?
    var fantasyViewModel: FantasyViewModel? = nil
    var rosterID: String? = nil
    let selectedYear: Int
    
    @State private var showStatsPopup = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Avatar section
            ZStack {
                if let url = avatarURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                }
                
                if isWinning {
                    Circle()
                        .strokeBorder(Color.gpGreen, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            
            // Manager name
            Text(managerName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Record
            Text(managerRecord)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            
            // Score with winning color
            Text(String(format: "%.2f", score))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isWinning ? .gpGreen : .red)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}