//
//  SleeperSetupView.swift
//  BigWarRoom
//
//  Sleeper credentials setup and management
//

import SwiftUI

struct SleeperSetupView: View {
    @StateObject private var viewModel = SleeperSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Status Section with Continue Button
                Section {
                    HStack {
                        Image(systemName: viewModel.hasValidCredentials ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(viewModel.hasValidCredentials ? .green : .orange)
                        
                        Text(viewModel.hasValidCredentials ? "Sleeper Connected" : "Sleeper Not Configured")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Instructions") {
                            viewModel.showInstructions()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    // Setup Complete - Show Continue Button
                    if viewModel.isSetupComplete {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Setup Complete!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            
                            Button("Continue to BigWarRoom") {
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .font(.headline)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    if !viewModel.hasValidCredentials {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("💡 Sleeper is much easier! Just need your username or user ID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Status")
                }
                
                // Quick Setup Section
                Section {
                    Button("Use Default Credentials (Gp's Account)") {
                        viewModel.fillDefaultCredentials()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                } header: {
                    Text("Quick Setup")
                } footer: {
                    Text("This will auto-fill with the default Sleeper credentials. You can modify them or use your own.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Credentials Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleeper Username")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Your Sleeper username (e.g., YourUsername)", text: $viewModel.username)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleeper User ID")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Your Sleeper User ID (e.g., 123456789)", text: $viewModel.userID)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.numberPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Season")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Season", selection: $viewModel.selectedSeason) {
                            Text("2024").tag("2024")
                            Text("2025").tag("2025")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    HStack {
                        Button("Save Credentials") {
                            viewModel.saveCredentials()
                        }
                        .disabled(!viewModel.canSaveCredentials)
                        
                        Spacer()
                        
                        if viewModel.hasValidCredentials {
                            Button("Validate") {
                                viewModel.validateCredentials()
                            }
                            .disabled(viewModel.isValidating)
                        }
                    }
                } header: {
                    Text("Sleeper Authentication")
                } footer: {
                    Text("Enter either your username OR user ID - not both. Sleeper automatically discovers all your leagues!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // League Cache Status (if has credentials)
                if viewModel.hasValidCredentials && viewModel.cachedLeagueCount > 0 {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                    .foregroundColor(.blue)
                                Text("Cached Leagues: \(viewModel.cachedLeagueCount)")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button("Refresh") {
                                    viewModel.refreshLeagueCache()
                                }
                                .font(.caption)
                            }
                            
                            Text("Leagues auto-discovered from your Sleeper account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Discovered Leagues")
                    } footer: {
                        Text("Unlike ESPN, Sleeper automatically finds all your leagues - no manual entry required!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Advanced Section with Confirmation
                Section {
                    Button("Clear Sleeper Credentials") {
                        viewModel.requestClearCredentialsOnly()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear Sleeper Cache") {
                        viewModel.requestClearCacheOnly()
                    }
                    .foregroundColor(.orange)
                    
                    Divider()
                    
                    Button("Clear All Sleeper Data") {
                        viewModel.requestClearCredentials()
                    }
                    .foregroundColor(.red)
                    .fontWeight(.bold)
                } header: {
                    Text("Reset Sleeper Data")
                } footer: {
                    Text("Clear specific Sleeper data or all Sleeper credentials and cached leagues.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
                SleeperInstructionsSheet()
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

// MARK: - Instructions Sheet

struct SleeperInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Why Sleeper is Easy
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("SLEEPER IS MUCH EASIER!")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Text("Sleeper has a public API that doesn't require authentication cookies. You just need your username or user ID - that's it!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Method 1 - Username (Recommended)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text("METHOD 1: USERNAME (RECOMMENDED)")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    InstructionStep(
                        number: "1",
                        title: "Open Sleeper Website",
                        description: "Go to sleeper.com in your web browser and log into your account",
                        icon: "globe"
                    )
                    
                    InstructionStep(
                        number: "2",
                        title: "View Your Profile",
                        description: "Click on your profile picture or name to go to your profile page",
                        icon: "person.circle"
                    )
                    
                    InstructionStep(
                        number: "3",
                        title: "Copy Username from URL",
                        description: "Look at the URL in your browser. It will show: sleeper.com/u/YourUsername - copy the 'YourUsername' part (e.g., 'john_doe', 'fantasyguru', etc.)",
                        icon: "link"
                    )
                    
                    Text("OR")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                    
                    // Method 2 - User ID
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "number.circle.fill")
                                .foregroundColor(.purple)
                            Text("METHOD 2: USER ID")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    InstructionStep(
                        number: "1",
                        title: "Open Sleeper Mobile App",
                        description: "Open the Sleeper app on your phone or tablet",
                        icon: "iphone"
                    )
                    
                    InstructionStep(
                        number: "2",
                        title: "Go to Settings",
                        description: "Tap your profile picture, then go to Settings → Account",
                        icon: "gearshape.fill"
                    )
                    
                    InstructionStep(
                        number: "3",
                        title: "Copy User ID",
                        description: "Your User ID is displayed as a long number (e.g., 123456789012345678). Tap to copy it.",
                        icon: "doc.on.doc"
                    )
                    
                    Divider()
                    
                    // What's the difference?
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Username vs User ID - What's the difference?", systemImage: "questionmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("**Username**: Easy to remember (e.g., 'fantasyguru'), but can be changed")
                        Text("**User ID**: Long number that never changes, more reliable for automation")
                        
                        Text("\nBoth work equally well! Choose whichever is easier for you to find.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    // What can BigWarRoom access?
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Why Sleeper is MUCH easier than ESPN", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("✅ **Auto-Discovery**: Automatically finds ALL your leagues")
                        Text("✅ **Zero League Setup**: No manual League ID entry required")
                        Text("✅ **Always Current**: New leagues appear automatically")
                        Text("✅ **Live draft data** - real-time picks, your turn notifications")
                        Text("✅ **Player information** - stats, projections, availability")
                        Text("✅ **Roster data** - your team, other teams in your leagues")
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("🆚 **ESPN Comparison:**")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        Text("❌ **ESPN**: Must manually add every League ID")
                        Text("❌ **ESPN**: Complex cookie setup that expires")
                        Text("❌ **ESPN**: No auto-discovery of leagues")
                        
                        Text("\n❌ **Cannot make changes** - BigWarRoom is read-only for both services")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Important Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Why Sleeper is Better", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("• **No authentication required** - public API that doesn't need cookies")
                        Text("• **Never expires** - set it once and you're done forever")
                        Text("• **Real-time updates** - instantly see new picks and league changes")
                        Text("• **Works with all leagues** - public and private leagues you're in")
                        Text("• **No browser setup** - just username/ID from your profile")
                        Text("• **More reliable** - doesn't break when cookies expire")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Troubleshooting", systemImage: "wrench.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("**Can't find username?** Look at sleeper.com/u/YourUsername when logged in")
                        Text("**User ID not showing?** Update your Sleeper app to the latest version")
                        Text("**Validation failing?** Make sure you entered the username exactly (case-sensitive)")
                        Text("**No leagues showing?** Ensure you're a member of fantasy football leagues for the selected season")
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Sleeper Setup Instructions")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SleeperSetupView()
}

#Preview("Instructions") {
    SleeperInstructionsSheet()
}