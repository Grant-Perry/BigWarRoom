import SwiftUI

struct DraftSelectionSection: View {
    @Bindable var viewModel: DraftRoomViewModel
    @Binding var selectedTab: Int
    @State private var showAllLeagues = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Select Draft")
                    .font(.headline)
                
                Spacer()
                
                // League count
                if !viewModel.allAvailableDrafts.isEmpty {
                    Text("\(viewModel.allAvailableDrafts.count) leagues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Your leagues (if available)
            if !viewModel.allAvailableDrafts.isEmpty {
                leaguesListSection
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var leaguesListSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAllLeagues.toggle()
                }
            } label: {
                HStack {
                    Text("Your Leagues")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: showAllLeagues ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
            }
            
            if showAllLeagues {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.allAvailableDrafts) { leagueWrapper in
                        CompactLeagueCard(
                            leagueWrapper: leagueWrapper,
                            isSelected: leagueWrapper.id == viewModel.selectedLeagueWrapper?.id,
                            onSelect: {
                                Task { 
                                    await viewModel.selectDraft(leagueWrapper)
                                    // Navigate to Fantasy tab after selecting league (updated index)
                                    await MainActor.run {
                                        selectedTab = 7 // Fantasy tab is now index 7
                                        // x Print("🏈 Auto-navigated to Fantasy tab after selecting league: \(leagueWrapper.league.name)")
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .onAppear {
            // Auto-expand when leagues are available
            if !viewModel.allAvailableDrafts.isEmpty {
                showAllLeagues = true
            }
        }
        .onChange(of: viewModel.allAvailableDrafts.count) { newCount in
            // Auto-expand when leagues become available
            if newCount > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAllLeagues = true
                }
            }
        }
    }
}