import SwiftUI

struct DraftStatusInfo: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isLiveMode {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Live")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            if !viewModel.allDraftPicks.isEmpty {
                Text("\(viewModel.allDraftPicks.count) picks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let myRosterID = viewModel.myRosterID {
                Text("Pick \(myRosterID)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}