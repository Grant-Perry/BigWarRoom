import SwiftUI

struct PlayerPositionBadge: View {
    let suggestion: Suggestion
    @Bindable var viewModel: DraftRoomViewModel
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
    var body: some View {
        Group {
            if let sleeperPlayer = viewModel.findSleeperPlayer(for: suggestion.player),
               let positionRank = PlayerDirectoryStore.shared.positionalRank(for: sleeperPlayer.playerID) {
                Text(positionRank)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(colorService.positionColor(for: suggestion.player.position.rawValue))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Text(suggestion.player.position.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(colorService.positionColor(for: suggestion.player.position.rawValue))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}