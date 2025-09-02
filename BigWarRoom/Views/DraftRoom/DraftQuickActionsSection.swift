import SwiftUI

struct DraftQuickActionsSection: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
            
            // Action buttons grid
            actionButtonsGrid
            
            // Draft stats summary (if connected)
            if !viewModel.allDraftPicks.isEmpty {
                draftProgressSummary
            }
            
            // Top 25 AI Suggestions Section
            TopSuggestionsSection(viewModel: viewModel, selectedTab: $selectedTab)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var actionButtonsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        
        return LazyVGrid(columns: columns, spacing: 12) {
            // Navigate to AI Suggestions
            NavigationButton(
                title: "AI Picks",
                subtitle: "Smart suggestions",
                icon: "wand.and.stars",
                color: .purple,
                action: { selectedTab = 1 }
            )
            
            // Navigate to Draft Board
            NavigationButton(
                title: "Draft Board",
                subtitle: "Round by round",
                icon: "sportscourt",
                color: .blue,
                action: { selectedTab = 3 }
            )
            
            // Navigate to Live Picks
            NavigationButton(
                title: "Live Picks",
                subtitle: "Real-time updates",
                icon: "list.bullet.rectangle.portrait",
                color: .green,
                action: { selectedTab = 2 }
            )
            
            // Navigate to My Roster
            NavigationButton(
                title: "My Roster",
                subtitle: "Team overview",
                icon: "person.fill",
                color: .orange,
                action: { selectedTab = 4 }
            )
        }
    }
    
    private var draftProgressSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Draft Progress")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.allDraftPicks.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Total Picks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.isMyTurn {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("YOUR TURN")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Make your pick!")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Waiting")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text("Other managers")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct NavigationButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}