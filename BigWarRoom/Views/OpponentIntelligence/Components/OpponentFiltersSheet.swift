//
//  OpponentFiltersSheet.swift
//  BigWarRoom
//
//  Filter options for opponent intelligence dashboard
//

import SwiftUI

/// Sheet for filtering and sorting opponent intelligence data
struct OpponentFiltersSheet: View {
    @ObservedObject var viewModel: OpponentIntelligenceViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Threat level filter
                threatLevelSection
                
                // Position filter
                positionSection
                
                // Sort options
                sortSection
                
                // Display options
                displayOptionsSection
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var threatLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Threat Level")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // All threats option
                FilterChip(
                    title: "All Levels",
                    isSelected: viewModel.selectedThreatLevel == nil,
                    color: .blue
                ) {
                    viewModel.setThreatLevelFilter(nil)
                }
                
                // Individual threat levels
                ForEach(ThreatLevel.allCases, id: \.self) { threat in
                    FilterChip(
                        title: threat.rawValue,
                        isSelected: viewModel.selectedThreatLevel == threat,
                        color: threat.color
                    ) {
                        viewModel.setThreatLevelFilter(threat)
                    }
                }
            }
        }
    }
    
    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(viewModel.availablePositions, id: \.self) { position in
                    FilterChip(
                        title: position,
                        isSelected: viewModel.selectedPosition == position,
                        color: positionColor(for: position)
                    ) {
                        viewModel.setPositionFilter(position)
                    }
                }
            }
        }
    }
    
    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort By")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(OpponentIntelligenceViewModel.SortMethod.allCases) { method in
                    FilterChip(
                        title: method.rawValue,
                        isSelected: viewModel.sortBy == method,
                        color: .purple
                    ) {
                        viewModel.setSortMethod(method)
                    }
                }
            }
        }
    }
    
    private var displayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Options")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            // Conflicts only toggle
            HStack {
                Image(systemName: viewModel.showConflictsOnly ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(viewModel.showConflictsOnly ? .green : .gray)
                    .font(.system(size: 20))
                
                Text("Show Conflicts Only")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.toggleConflictsOnly()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetFilters() {
        viewModel.setThreatLevelFilter(nil)
        viewModel.setPositionFilter("All")
        viewModel.setSortMethod(.threatLevel)
        if viewModel.showConflictsOnly {
            viewModel.toggleConflictsOnly()
        }
    }
    
    private func positionColor(for position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
}

// MARK: - Filter Chip Component

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? color : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(color, lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("Opponent Filters Sheet") {
    OpponentFiltersSheet(viewModel: OpponentIntelligenceViewModel())
}