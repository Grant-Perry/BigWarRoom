//
//  AllLivePlayersFiltersSheet.swift
//  BigWarRoom
//
//  Filter options for All Rostered Players view - modeled after OpponentFiltersSheet
//

import SwiftUI

/// Sheet for filtering and sorting all live players data
struct AllLivePlayersFiltersSheet: View {
    @ObservedObject var allLivePlayersViewModel: AllLivePlayersViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // BG8 background matching the parent view
                Image("BG8")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea(.all)
                
                // Background overlay
                Color.black.opacity(0.3).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Position filter
                        positionSection
                        
                        // Sort options
                        sortSection
                        
                        // Display options
                        displayOptionsSection
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
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
    
    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                    FilterChip(
                        title: position.displayName,
                        isSelected: allLivePlayersViewModel.selectedPosition == position,
                        color: positionColor(for: position.rawValue)
                    ) {
                        allLivePlayersViewModel.setPositionFilter(position)
                    }
                }
            }
        }
    }
    
    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort By")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(AllLivePlayersViewModel.SortingMethod.allCases) { method in
                    FilterChip(
                        title: method.displayName,
                        isSelected: allLivePlayersViewModel.sortingMethod == method,
                        color: .purple
                    ) {
                        allLivePlayersViewModel.setSortingMethod(method)
                    }
                }
            }
            
            // Sort direction
            HStack(spacing: 16) {
                Text("Direction")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 12) {
                    FilterChip(
                        title: "High to Low",
                        isSelected: allLivePlayersViewModel.sortHighToLow,
                        color: .blue
                    ) {
                        allLivePlayersViewModel.setSortDirection(highToLow: true)
                    }
                    
                    FilterChip(
                        title: "Low to High",
                        isSelected: !allLivePlayersViewModel.sortHighToLow,
                        color: .blue
                    ) {
                        allLivePlayersViewModel.setSortDirection(highToLow: false)
                    }
                }
            }
        }
    }
    
    private var displayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display Options")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            // Active players only toggle
            HStack {
                Image(systemName: allLivePlayersViewModel.showActiveOnly ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(allLivePlayersViewModel.showActiveOnly ? .green : .gray)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Active Players Only")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Only players in live games")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                allLivePlayersViewModel.setShowActiveOnly(!allLivePlayersViewModel.showActiveOnly)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetFilters() {
        allLivePlayersViewModel.setPositionFilter(.all)
        allLivePlayersViewModel.setSortingMethod(.score)
        allLivePlayersViewModel.setSortDirection(highToLow: true)
        allLivePlayersViewModel.setShowActiveOnly(false)
    }
    
    private func positionColor(for position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
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

#Preview("All Live Players Filters Sheet") {
    AllLivePlayersFiltersSheet(allLivePlayersViewModel: AllLivePlayersViewModel.shared)
        .preferredColorScheme(.dark)
}
