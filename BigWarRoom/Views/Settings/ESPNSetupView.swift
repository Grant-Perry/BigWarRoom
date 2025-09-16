//
//  ESPNSetupView.swift
//  BigWarRoom
//
//  ESPN credentials setup and management - Clean MVVM Coordinator
//

import SwiftUI

struct ESPNSetupView: View {
    @StateObject private var viewModel = ESPNSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Status Section with Continue Button
                ESPNStatusSection(viewModel: viewModel) {
                    dismiss()
                }
                
                // Quick Setup Section
                ESPNQuickSetupSection(viewModel: viewModel)
                
                // Credentials Section
                ESPNCredentialsSection(viewModel: viewModel)
                
                // League IDs Section
                ESPNLeagueIDsSection(viewModel: viewModel)
                
                // Advanced Section with Confirmation
                ESPNAdvancedSection(viewModel: viewModel)
            }
            .navigationTitle("ESPN Setup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSetupComplete {
                        Button("Continue") {
                            dismiss()
                        }
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingInstructions) {
                ESPNInstructionsSheet()
            }
            .alert("Validation Result", isPresented: $viewModel.showingValidation) {
                Button("OK") {
                    viewModel.dismissValidation()
                }
            } message: {
                Text(viewModel.validationMessage)
            }
            .alert("Confirm Clear Action", isPresented: $viewModel.showingClearConfirmation) {
                Button("Clear", role: .destructive) {
                    viewModel.confirmClearAction()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelClearAction()
                }
            } message: {
                Text("Are you sure you want to clear this data? This action cannot be undone.")
            }
            .alert("Action Result", isPresented: $viewModel.showingClearResult) {
                Button("OK") {
                    viewModel.dismissClearResult()
                }
            } message: {
                Text(viewModel.clearResultMessage)
            }
            .overlay {
                if viewModel.isValidating {
                    ProgressView("Validating credentials...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ESPNSetupView()
}