//
//  PlayoffBracketGameHeader.swift
//  BigWarRoom
//
//  Game day/status header for playoff bracket matchups
//

import SwiftUI

struct PlayoffBracketGameHeader: View {
    let game: PlayoffGame
    let shouldShowGameTime: (Date) -> Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if game.isLive {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                
                Text(game.status.displayText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            } else if game.isCompleted {
                Text("FINAL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text(formatGameDate(game.gameDate))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.bottom, 4)
    }
    
    private func formatGameDate(_ date: Date) -> String {
        // If game time is TBD (defaults to midnight), only show the date.
        if !shouldShowGameTime(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"  // "Saturday, Jan 10"
            return formatter.string(from: date)
        }
        
        // Otherwise, show date and time
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d • h:mm a"  // "Sat, Jan 10 • 4:30 PM"
        return formatter.string(from: date)
    }
}