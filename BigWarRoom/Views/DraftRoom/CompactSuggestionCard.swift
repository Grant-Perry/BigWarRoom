import SwiftUI

struct CompactSuggestionCard: View {
    let suggestion: Suggestion
    @ObservedObject var viewModel: DraftRoomViewModel
    let onShowStats: (Player) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // Player headshot (smaller)
            PlayerImageForSuggestion(player: suggestion.player, viewModel: viewModel)
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                PlayerInfoRow(suggestion: suggestion, viewModel: viewModel)
                
                // Fantasy rank and tier
                PlayerStatsRow(suggestion: suggestion, viewModel: viewModel)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
                .opacity(0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onShowStats(suggestion.player)
        }
        .contextMenu {
            SuggestionContextMenu(suggestion: suggestion, viewModel: viewModel, onShowStats: onShowStats)
        }
    }
}