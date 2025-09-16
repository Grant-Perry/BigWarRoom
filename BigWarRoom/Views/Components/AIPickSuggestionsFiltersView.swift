//
//  AIPickSuggestionsFiltersView.swift
//  BigWarRoom
//
//  Filters section component for AIPickSuggestionsView
//

import SwiftUI

/// Filters section with sort method and position filters
struct AIPickSuggestionsFiltersView: View {
    let viewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sort Method Toggle
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Strategy Mode")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ForEach(SortMethod.allCases) { method in
                        Button {
                            viewModel.updateSortMethod(method)
                        } label: {
                            VStack(spacing: 4) {
                                Text(method.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text(method.description)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                viewModel.selectedSortMethod == method 
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(.systemGray5)], startPoint: .top, endPoint: .bottom)
                            )
                            .foregroundColor(
                                viewModel.selectedSortMethod == method 
                                ? .white 
                                : .primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            
            // Position Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Position Filter")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PositionFilter.allCases) { filter in
                            Button {
                                viewModel.updatePositionFilter(filter)
                            } label: {
                                Text(filter.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.selectedPositionFilter == filter 
                                        ? Color.blue 
                                        : Color(.systemGray5)
                                    )
                                    .foregroundColor(
                                        viewModel.selectedPositionFilter == filter 
                                        ? .white 
                                        : .primary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}