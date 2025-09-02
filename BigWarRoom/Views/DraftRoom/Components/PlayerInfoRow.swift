import SwiftUI

struct PlayerInfoRow: View {
    let suggestion: Suggestion
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        HStack(spacing: 6) {
            Text("\(suggestion.player.firstInitial) \(suggestion.player.lastName)")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Position
            PlayerPositionBadge(suggestion: suggestion, viewModel: viewModel)
            
            Spacer()
            
            // Team logo (smaller)
            TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                .frame(width: 24, height: 24)
        }
    }
}