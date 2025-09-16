//
//  SleeperSetupView.swift
//  BigWarRoom
//
//  Sleeper credentials setup and management - Pure coordinator view
//

import SwiftUI

struct SleeperSetupView: View {
    @StateObject private var sleeperSetupViewModel = SleeperSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Status Section with Continue Button
                StatusSectionView(
                    hasValidCredentials: sleeperSetupViewModel.hasValidCredentials,
                    isSetupComplete: sleeperSetupViewModel.isSetupComplete,
                    onInstructionsTapped: {
                        sleeperSetupViewModel.showInstructions()
                    },
                    onContinueTapped: {
                        navigateToMissionControl()
                        dismiss()
                    }
                )
                
                // Quick Setup Section
                QuickSetupSectionView(
                    onDefaultCredentialsTapped: {
                        sleeperSetupViewModel.fillDefaultCredentials()
                    }
                )
                
                // Credentials Section
                CredentialsSectionView(
                    username: $sleeperSetupViewModel.username,
                    userID: $sleeperSetupViewModel.userID,
                    selectedSeason: $sleeperSetupViewModel.selectedSeason,
                    hasValidCredentials: sleeperSetupViewModel.hasValidCredentials,
                    canSaveCredentials: sleeperSetupViewModel.canSaveCredentials,
                    isValidating: sleeperSetupViewModel.isValidating,
                    onSaveCredentials: {
                        sleeperSetupViewModel.saveCredentials()
                    },
                    onValidateCredentials: {
                        sleeperSetupViewModel.validateCredentials()
                    }
                )
                
                // League Cache Section (conditional)
                LeagueCacheSectionView(
                    hasValidCredentials: sleeperSetupViewModel.hasValidCredentials,
                    cachedLeagueCount: sleeperSetupViewModel.cachedLeagueCount,
                    onRefreshCache: {
                        sleeperSetupViewModel.refreshLeagueCache()
                    }
                )
                
                // Reset Data Section
                ResetDataSectionView(
                    onClearCredentialsOnly: {
                        sleeperSetupViewModel.requestClearCredentialsOnly()
                    },
                    onClearCacheOnly: {
                        sleeperSetupViewModel.requestClearCacheOnly()
                    },
                    onClearAllData: {
                        sleeperSetupViewModel.requestClearCredentials()
                    }
                )
            }
            .navigationTitle("Sleeper Setup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if sleeperSetupViewModel.isSetupComplete {
                        Button("Continue") {
                            navigateToMissionControl()
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
            .sheet(isPresented: $sleeperSetupViewModel.showingInstructions) {
                SleeperInstructionsSheet()
            }
            .alert("Validation Result", isPresented: $sleeperSetupViewModel.showingValidation) {
                Button("OK") {
                    sleeperSetupViewModel.dismissValidation()
                }
            } message: {
                Text(sleeperSetupViewModel.validationMessage)
            }
            .alert("Confirm Clear Action", isPresented: $sleeperSetupViewModel.showingClearConfirmation) {
                Button("Clear", role: .destructive) {
                    sleeperSetupViewModel.confirmClearAction()
                }
                Button("Cancel", role: .cancel) {
                    sleeperSetupViewModel.cancelClearAction()
                }
            } message: {
                Text("Are you sure you want to clear this data? This action cannot be undone.")
            }
            .alert("Action Result", isPresented: $sleeperSetupViewModel.showingClearResult) {
                Button("OK") {
                    sleeperSetupViewModel.dismissClearResult()
                }
            } message: {
                Text(sleeperSetupViewModel.clearResultMessage)
            }
            .overlay {
                ValidationOverlayView(
                    isValidating: sleeperSetupViewModel.isValidating,
                    message: "Validating credentials..."
                )
            }
        }
    }
    
    // MARK: - Navigation Actions
    
    private func navigateToMissionControl() {
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
    }
}