//
//  GameDetailView.swift
//  BigWarRoom
//
//  Detail view for individual NFL games showing fantasy players
//

import SwiftUI

struct GameDetailView: View {
    let game: ScheduleGame
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Fantasy Players")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Coming soon: Fantasy players in \(game.awayTeam) @ \(game.homeTeam)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Game Detail") {
    GameDetailView(
        game: ScheduleGame(
            id: "KC@BUF",
            awayTeam: "KC",
            homeTeam: "BUF",
            awayScore: 21,
            homeScore: 17,
            gameStatus: "in",
            gameTime: "Q3 8:42",
            startDate: Date(),
            isLive: true
        )
    )
}