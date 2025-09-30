import SwiftUI

struct CompactSuggestionCard: View {
    let suggestion: Suggestion
    @ObservedObject var viewModel: DraftRoomViewModel
    let onShowStats: ((Player) -> Void)? // 🔥 DEATH TO SHEETS: Made optional for NavigationLink usage
    
    var body: some View {
        // 🔥 DEATH TO SHEETS: Use NavigationLink instead of onTapGesture
        Group {
            if let sleeperPlayer = viewModel.findSleeperPlayer(for: suggestion.player) {
                NavigationLink(
                    destination: PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: suggestion.player.team)
                    )
                ) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent // No navigation if can't find player
            }
        }
        .contextMenu {
            SuggestionContextMenu(
                suggestion: suggestion,
                viewModel: viewModel,
                onShowStats: onShowStats ?? { _ in } // 🔥 DEATH TO SHEETS: Provide empty closure if nil
            )
        }
    }
    
    // 🔥 DEATH TO SHEETS: Extract card content to reusable computed property
    private var cardContent: some View {
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
    }
}