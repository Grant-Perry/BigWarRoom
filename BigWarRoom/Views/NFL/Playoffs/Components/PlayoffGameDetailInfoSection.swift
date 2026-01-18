//
//  PlayoffGameDetailInfoSection.swift
//  BigWarRoom
//
//  Center info section for playoff game detail card
//

import SwiftUI

/// Center game info section (date, time, venue, network)
struct PlayoffGameDetailInfoSection: View {
    let game: PlayoffGame
    
    var body: some View {
        VStack(spacing: 3) {
            // Day name
            if !game.smartFormattedDate.isEmpty, !game.isLive {
                Text(game.smartFormattedDate.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            // LIVE GAME STATUS or time
            if game.isLive, case .inProgress(let quarter, let time) = game.status {
                VStack(spacing: 2) {
                    Text(quarter.uppercased())
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.gpGreen)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    
                    if !time.isEmpty {
                        Text(time)
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    }
                    
                    // Down & Distance
                    if game.isLive {
                        if let down = game.liveSituation?.down ?? game.lastKnownDownDistance?.down,
                           let distance = game.liveSituation?.distance ?? game.lastKnownDownDistance?.distance,
                           down > 0, distance > 0 {
                            let suffix: String = {
                                switch down {
                                case 1: return "st"
                                case 2: return "nd"
                                case 3: return "rd"
                                default: return "th"
                                }
                            }()
                            
                            Text("\(down)\(suffix) & \(distance)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                    }
                }
            } else {
                Text(game.formattedTime)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            // Stadium
            if let venue = game.venue, let venueName = venue.fullName, !game.isLive {
                Text(venueName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                
                // City, State
                if let city = venue.city, let state = venue.state {
                    Text("\(city), \(state)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                } else if let city = venue.city {
                    Text(city)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
            
            // Network
            if let broadcasts = game.broadcasts, !broadcasts.isEmpty, !game.isLive {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(broadcasts.joined(separator: ", "))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}