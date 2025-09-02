import SwiftUI

struct ManualPositionPicker: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                Text("Select your draft position:")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            // Position grid
            let teamCount = viewModel.maxTeamsInDraft
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(teamCount, 6))
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...teamCount, id: \.self) { position in
                    Button("\(position)") {
                        viewModel.selectedManualPosition = position
                    }
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(width: 40, height: 40)
                    .background(
                        viewModel.selectedManualPosition == position ? 
                        Color.blue : Color(.systemGray5)
                    )
                    .foregroundColor(
                        viewModel.selectedManualPosition == position ? 
                        .white : .primary
                    )
                    .clipShape(Circle())
                }
            }
            
            HStack(spacing: 12) {
                Button("Set Position \(viewModel.selectedManualPosition)") {
                    viewModel.setManualDraftPosition(viewModel.selectedManualPosition)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Skip") {
                    viewModel.dismissManualPositionPrompt()
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}