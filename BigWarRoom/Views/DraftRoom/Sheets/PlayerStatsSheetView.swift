import SwiftUI

struct PlayerStatsSheetView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    var body: some View {
        NavigationView {
            PlayerStatsCardView(player: player, team: team)
                .navigationTitle("Player Stats")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            // This will be handled by the parent's dismiss
                        }
                    }
                }
        }
    }
}

