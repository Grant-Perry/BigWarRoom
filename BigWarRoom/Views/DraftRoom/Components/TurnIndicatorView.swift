import SwiftUI

struct TurnIndicatorView: View {
    @Bindable var viewModel: DraftRoomViewModel
    
    var body: some View {
        Group {
            if viewModel.isMyTurn {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("YOUR TURN")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1))
                .clipShape(Capsule())
            } else if viewModel.isLiveMode {
                PollingCountdownDial(
                    countdown: viewModel.pollingCountdown,
                    maxInterval: viewModel.maxPollingInterval,
                    isPolling: viewModel.connectionStatus == .connected,
                    onRefresh: {
                        Task { await viewModel.forceRefresh() }
                    }
                )
            }
        }
    }
}