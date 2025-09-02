import SwiftUI

struct PlayerPositionBadge: View {
    let suggestion: Suggestion
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        Group {
            if let sleeperPlayer = viewModel.findSleeperPlayer(for: suggestion.player),
               let positionRank = sleeperPlayer.positionalRank {
                Text(positionRank)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(suggestion.player.position.displayColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Text(suggestion.player.position.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(suggestion.player.position.displayColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}