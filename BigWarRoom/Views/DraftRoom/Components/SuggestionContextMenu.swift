import SwiftUI

struct SuggestionContextMenu: View {
    let suggestion: Suggestion
    @ObservedObject var viewModel: DraftRoomViewModel
    let onShowStats: (Player) -> Void
    
    var body: some View {
        Group {
            Button("Lock as My Pick") {
                viewModel.lockPlayerAsPick(suggestion)
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            
            Button("Add to Feed") {
                viewModel.addPlayerToFeed(suggestion)
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            
            Button("View Stats") {
                onShowStats(suggestion.player)
            }
        }
    }
}