import SwiftUI

struct ESPNDraftPickSelectionSheet: View {
    let leagueName: String
    let maxTeams: Int
    @Binding var selectedPick: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header info
                VStack(spacing: 8) {
                    Text("Select Draft Position")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(leagueName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Choose your draft position to start tracking picks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Position picker grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: min(maxTeams, 4))
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...maxTeams, id: \.self) { position in
                        Button("\(position)") {
                            selectedPick = position
                        }
                        .font(.title3)
                        .fontWeight(.medium)
                        .frame(width: 60, height: 60)
                        .background(
                            selectedPick == position ? 
                            Color.blue : Color(.systemGray5)
                        )
                        .foregroundColor(
                            selectedPick == position ? 
                            .white : .primary
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedPick == position ? Color.blue : Color.clear,
                                    lineWidth: 3
                                )
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Confirm Position \(selectedPick)") {
                        onConfirm(selectedPick)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}