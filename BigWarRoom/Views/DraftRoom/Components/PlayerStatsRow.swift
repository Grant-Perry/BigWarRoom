import SwiftUI

struct PlayerStatsRow: View {
    let suggestion: Suggestion
    @Bindable var viewModel: DraftRoomViewModel
    
    var body: some View {
        HStack(spacing: 6) {
            if let sleeperPlayer = viewModel.findSleeperPlayer(for: suggestion.player),
               let searchRank = sleeperPlayer.searchRank {
                Text("Rank \(searchRank)")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            
            Text("Tier \(suggestion.player.tier)")
                .font(.caption2)
                .foregroundColor(suggestion.player.tierColor)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}