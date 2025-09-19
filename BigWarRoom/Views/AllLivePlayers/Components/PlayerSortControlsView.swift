//
//  PlayerSortControlsView.swift
//  BigWarRoom
//
//  Sorting controls for All Live Players
//

import SwiftUI

/// Sorting method and direction controls
struct PlayerSortControlsView: View {
    @ObservedObject var viewModel: AllLivePlayersViewModel
    @Binding var sortHighToLow: Bool
    let onSortChange: () -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            // Sort method selector
            HStack(spacing: 2) {
                Text("Sort:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(AllLivePlayersViewModel.SortingMethod.allCases) { method in
                        Button(action: {
                            // 🔥 FIXED: Proper sort method change with animation reset
                            viewModel.setSortingMethod(method)
                            onSortChange()
                        }) {
                            HStack {
                                Text(method.displayName)
                                if viewModel.sortingMethod == method {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.sortingMethod.displayName)
                            .fontWeight(.semibold)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 60)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            
            // Sort direction toggle
            Button(action: {
                // 🔥 FIXED: Update ViewModel first, then sync local binding
                let newDirection = !viewModel.sortHighToLow
                viewModel.setSortDirection(highToLow: newDirection)
                sortHighToLow = newDirection // Sync the binding
                onSortChange()
            }) {
                Text(viewModel.sortDirectionText)
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 65)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .onChange(of: viewModel.sortingMethod) { _, _ in
            // 🔥 NEW: Reset animations when sorting method changes from ViewModel
            onSortChange()
        }
        .onChange(of: viewModel.sortHighToLow) { _, newValue in
            // 🔥 FIXED: Keep binding in sync with ViewModel
            sortHighToLow = newValue
        }
    }
}

#Preview {
    PlayerSortControlsView(
        viewModel: AllLivePlayersViewModel.shared,
        sortHighToLow: .constant(true),
        onSortChange: {}
    )
}