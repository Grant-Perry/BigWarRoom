//
//  ESPNDraftPickSelectionView.swift
//  BigWarRoom
//
//  ESPN Draft Pick Selection Sheet
//

import SwiftUI

struct ESPNDraftPickSelectionView: View {
    let leagueName: String
    let maxTeams: Int
    @Binding var selectedPick: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    AppConstants.espnLogo
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 8) {
                        Text("Draft Pick Selection")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(leagueName)
                            .font(.headline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Text("Select your draft position to enable pick tracking and alerts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Pick Selection Grid
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose Your Pick")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: min(5, maxTeams))
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...maxTeams, id: \.self) { pick in
                            Button {
                                selectedPick = pick
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(pick)")
                                        .font(.system(size: 20, weight: .bold))
                                    Text("Pick")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .frame(width: 55, height: 55)
                                .background(
                                    selectedPick == pick ?
                                    Color.red : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    selectedPick == pick ?
                                    .white : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedPick == pick ?
                                            Color.red.opacity(0.8) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            }
                            .scaleEffect(selectedPick == pick ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: selectedPick)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Selected Pick Display
                if selectedPick > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Selected: Pick \(selectedPick)")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text("You'll receive alerts when it's your turn")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Confirm Pick \(selectedPick)") {
                        onConfirm(selectedPick)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(selectedPick == 0)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("ESPN Draft")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
        }
    }
}