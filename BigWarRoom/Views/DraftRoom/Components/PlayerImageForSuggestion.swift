import SwiftUI

struct PlayerImageForSuggestion: View {
    let player: Player
    @ObservedObject var viewModel: DraftRoomViewModel
    let size: CGFloat = 40
    
    var body: some View {
        Group {
            if let sleeperPlayer = viewModel.findSleeperPlayer(for: player) {
                PlayerImageView(
                    player: sleeperPlayer,
                    size: size,
                    team: NFLTeam.team(for: player.team)
                )
            } else {
                Circle()
                    .fill(NFLTeam.team(for: player.team)?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        Text(player.firstInitial)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(NFLTeam.team(for: player.team)?.accentColor ?? .white)
                    )
                    .frame(width: size, height: size)
            }
        }
    }
}