import SwiftUI

struct ActiveDraftSection: View {
    @Bindable var viewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Draft header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let selectedDraft = viewModel.selectedDraft {
                        Text(selectedDraft.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        DraftStatusInfo(viewModel: viewModel)
                    } else {
                        Text("Manual Draft")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Monitoring picks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Turn indicator or polling status
                TurnIndicatorView(viewModel: viewModel)
            }
            
            // Manual position picker (if needed)
            if viewModel.manualDraftNeedsPosition {
                ManualPositionPicker(viewModel: viewModel)
            }
        }
        .padding()
        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}