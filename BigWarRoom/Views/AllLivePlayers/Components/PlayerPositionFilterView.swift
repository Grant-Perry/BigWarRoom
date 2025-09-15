//
//  PlayerPositionFilterView.swift
//  BigWarRoom
//
//  Position filter dropdown for All Live Players
//

import SwiftUI

/// Position filter dropdown menu component
struct PlayerPositionFilterView: View {
    @ObservedObject var viewModel: AllLivePlayersViewModel
    let onPositionChange: () -> Void
    
    var body: some View {
        Menu {
            ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.setPositionFilter(position)
                        onPositionChange()
                    }
                }) {
                    HStack {
                        Text(position.displayName)
                        if viewModel.selectedPosition == position {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedPosition.displayName)
                    .fontWeight(.semibold)
                    .font(.subheadline)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gpGreen.opacity(0.1))
            .foregroundColor(.gpGreen)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    PlayerPositionFilterView(
        viewModel: AllLivePlayersViewModel.shared,
        onPositionChange: {}
    )
}