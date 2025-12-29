//
//  PlayerSortingControlsView.swift
//  BigWarRoom
//
//  🔥 DRY COMPONENT: Reusable player sorting controls
//  Used across fantasy views for consistent sorting UI
//

import SwiftUI

/// **PlayerSortingControlsView**
/// 
/// DRY component for player sorting controls with:
/// - Position, Score, Name, Team sorting options
/// - A-Z / Z-A toggle functionality  
/// - Consistent styling across the app
/// - Reusable in any fantasy view
struct PlayerSortingControlsView: View {
    @Binding var sortingMethod: MatchupSortingMethod
    @Binding var sortHighToLow: Bool
    
    var body: some View {
        HStack {
            Spacer()
            
            // Sorting controls
            HStack(spacing: 10) {
                // Sort method picker
                Menu {
                    ForEach(MatchupSortingMethod.allCases) { method in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                sortingMethod = method
                                // FIXED: Default to descending for score sorting
                                if method == .score {
                                    sortHighToLow = true // Always default to high-to-low for scores
                                }
                            }
                        }) {
                            HStack {
                                Text(method.displayName)
                                if sortingMethod == method {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(sortingMethod.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Sort direction toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sortHighToLow.toggle()
                    }
                }) {
                    Text(sortDirectionText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    /// Dynamic sort direction text based on current method and direction
    private var sortDirectionText: String {
        switch sortingMethod {
        case .score, .recentActivity:
            return sortHighToLow ? "↓" : "↑"
        case .name, .position, .team:
            return sortHighToLow ? "Z-A" : "A-Z"
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sortMethod: MatchupSortingMethod = .position
    @Previewable @State var sortHigh = false
    
    return VStack(spacing: 20) {
        PlayerSortingControlsView(
            sortingMethod: $sortMethod,
            sortHighToLow: $sortHigh
        )
        
        Text("Current: \(sortMethod.displayName) - \(sortHigh ? "Z-A" : "A-Z")")
    }
    .padding()
    .background(Color.black)
}