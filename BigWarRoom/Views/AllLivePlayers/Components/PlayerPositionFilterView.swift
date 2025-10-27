//
//  PlayerPositionFilterView.swift
//  BigWarRoom
//
//  Position filter dropdown for All Live Players
//

import SwiftUI

/// Position filter dropdown menu component
struct PlayerPositionFilterView: View {
    @Bindable var allLivePlayersViewModel: AllLivePlayersViewModel
    let onPositionChange: () -> Void
    
    var body: some View {
        Menu {
            ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        allLivePlayersViewModel.setPositionFilter(position)
                        onPositionChange()
                    }
                }) {
                    HStack {
                        Text(position.displayName)
                        if allLivePlayersViewModel.selectedPosition == position {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(allLivePlayersViewModel.selectedPosition.displayName)
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
        allLivePlayersViewModel: AllLivePlayersViewModel.shared,
        onPositionChange: {}
    )
}