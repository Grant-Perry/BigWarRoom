import SwiftUI

struct TopSuggestionsSection: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top AI Suggestions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !viewModel.suggestions.isEmpty {
                    Text("Showing \(min(viewModel.suggestions.count, 5))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.suggestions.isEmpty {
                loadingStateView
            } else {
                suggestionsListView
            }
        }
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading AI suggestions...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private var suggestionsListView: some View {
        VStack(spacing: 8) {
            // Show top 5 suggestions in compact format
            LazyVStack(spacing: 8) {
                ForEach(viewModel.getTopSuggestions()) { suggestion in
                    CompactSuggestionCard(
                        suggestion: suggestion,
                        viewModel: viewModel,
                        onShowStats: nil
                    )
                }
            }
            
            // "View All" button to navigate to AI Picks tab
            if viewModel.hasMoreSuggestions() {
                viewAllButton
            }
        }
    }
    
    private var viewAllButton: some View {
        Button {
            selectedTab = 5 // Switch to AI Picks tab (now index 5)
        } label: {
            HStack {
                Text("View All \(viewModel.suggestions.count) Suggestions")
                    .font(.callout)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.caption)
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}