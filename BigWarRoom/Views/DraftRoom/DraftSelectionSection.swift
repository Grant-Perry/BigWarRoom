import SwiftUI

struct DraftSelectionSection: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @State private var showAllLeagues = false
    @State private var manualDraftID: String = ""
    @State private var isConnectingToDraft = false
    
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
            
            // Manual draft entry
            manualDraftEntrySection
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
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.allAvailableDrafts) { leagueWrapper in
                            CompactLeagueCard(
                                leagueWrapper: leagueWrapper,
                                isSelected: leagueWrapper.id == viewModel.selectedLeagueWrapper?.id,
                                onSelect: {
                                    Task { await viewModel.selectDraft(leagueWrapper) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 300)
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
    
    private var manualDraftEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Manual Draft ID")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 8) {
                TextField("Enter any draft ID", text: $manualDraftID)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .disabled(isConnectingToDraft)
                
                Button(isConnectingToDraft ? "..." : "Connect") {
                    Task {
                        isConnectingToDraft = true
                        await viewModel.connectToManualDraft(draftID: manualDraftID)
                        isConnectingToDraft = false
                    }
                }
                .font(.callout)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(manualDraftID.isEmpty || isConnectingToDraft)
            }
        }
    }
}