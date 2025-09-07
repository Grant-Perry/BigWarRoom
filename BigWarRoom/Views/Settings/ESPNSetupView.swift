//
//  ESPNSetupView.swift
//  BigWarRoom
//
//  ESPN credentials setup and management
//

import SwiftUI

struct ESPNSetupView: View {
    @StateObject private var viewModel = ESPNSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Status Section with Continue Button
                Section {
                    HStack {
                        Image(systemName: viewModel.hasValidCredentials ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(viewModel.hasValidCredentials ? .green : .orange)
                        
                        Text(viewModel.hasValidCredentials ? "ESPN Connected" : "ESPN Not Configured")
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
                            
                            Button("Continue to Mission Control") {
                                // 🔥 FIX: Navigate to Mission Control tab (0) instead of just dismissing
                                NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
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
                                Text("💡 Tip: Use the 'ESPN Cookie Finder' Chrome extension for easiest setup!")
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
                    Text("This will auto-fill with the default ESPN credentials. You can modify them or use your own.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Credentials Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SWID")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Your ESPN SWID (e.g., {ABC-123-DEF})", text: $viewModel.swid)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ESPN_S2 Cookie")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Your ESPN_S2 authentication cookie", text: $viewModel.espnS2, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
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
                    Text("ESPN Authentication")
                } footer: {
                    Text("Your ESPN credentials are stored securely in Keychain and never shared.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // League IDs Section
                Section {
                    // Explanation Block
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("REQUIRED: Manual League Setup")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        Text("Unlike Sleeper, ESPN requires you to manually add each League ID:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Find League ID in your ESPN league URL")
                            Text("• Add each league you want to access")
                            Text("• League IDs are saved permanently") 
                            Text("• You can add/remove leagues anytime")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Current League IDs
                    ForEach(viewModel.leagueIDs, id: \.self) { leagueID in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(leagueID)
                                    .font(.monospaced(.body)())
                                Text("ESPN League")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Remove") {
                                viewModel.removeLeagueID(leagueID)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Add New League
                    HStack {
                        TextField("League ID (e.g., 1234567890)", text: $viewModel.newLeagueID)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        
                        Button("Add League") {
                            viewModel.addLeagueID()
                        }
                        .disabled(!viewModel.canAddLeague)
                    }
                    
                    // Default League IDs Section
                    Button("Add Gp's Default Leagues") {
                        viewModel.addDefaultLeagueIDs()
                    }
                    .foregroundColor(.blue)
                } header: {
                    Text("League Management (ESPN Only)")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("📋 **ESPN**: You must manually add every league ID")
                        Text("🚀 **Sleeper**: Auto-discovers all leagues (no setup needed)")
                        Text("\nLeague IDs are found in ESPN URLs: fantasy.espn.com/football/league?leagueId=1234567890")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Advanced Section with Confirmation
                Section {
                    Button("Clear ESPN Credentials") {
                        viewModel.requestClearCredentialsOnly()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear ESPN League IDs") {
                        viewModel.requestClearLeagueIDsOnly()
                    }
                    .foregroundColor(.orange)
                    
                    Divider()
                    
                    Button("Clear All ESPN Data") {
                        viewModel.requestClearCredentials()
                    }
                    .foregroundColor(.red)
                    .fontWeight(.bold)
                } header: {
                    Text("Reset ESPN Data")
                } footer: {
                    Text("Clear specific ESPN data or all ESPN credentials and league IDs.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

// MARK: - Instructions Sheet

struct ESPNInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Method 1 - Chrome Extension (Easiest)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("RECOMMENDED METHOD")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Text("The ESPN Cookie Finder Chrome extension automatically extracts your credentials with one click - no manual copying needed!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        InstructionStep(
                            number: "1",
                            title: "Install ESPN Cookie Finder Extension",
                            description: "Go to Chrome Web Store and search for 'ESPN Cookie Finder' by Hashtag Fantasy Sports. It has a 4.4-star rating and 1,000+ users. Click 'Add to Chrome' to install.",
                            icon: "globe"
                        )
                        
                        InstructionStep(
                            number: "2", 
                            title: "Log into ESPN Fantasy",
                            description: "Open Chrome, go to fantasy.espn.com, and log into your ESPN account. Navigate to any of your fantasy football leagues.",
                            icon: "safari"
                        )
                        
                        InstructionStep(
                            number: "3",
                            title: "Run the Extension", 
                            description: "Click the ESPN Cookie Finder extension icon in your Chrome toolbar (next to the address bar). The extension will automatically detect and display your SWID and ESPN_S2 values in a popup window.",
                            icon: "cursor.rays"
                        )
                        
                        InstructionStep(
                            number: "4",
                            title: "Copy Values to BigWarRoom",
                            description: "Copy the SWID and ESPN_S2 values from the extension popup and paste them into the BigWarRoom ESPN setup form. Also note your League IDs from your ESPN league URLs.",
                            icon: "doc.on.doc"
                        )
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    
                    Divider()
                    
                    // Method 2 - Manual Method
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.blue)
                            Text("MANUAL METHOD")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Text("If you can't use the Chrome extension or prefer the manual approach:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Manual Steps
                    InstructionStep(
                        number: "1",
                        title: "Open ESPN Fantasy Football",
                        description: "Go to fantasy.espn.com in any web browser (Chrome, Safari, Edge, Firefox) and log into your account. Navigate to one of your fantasy football leagues.",
                        icon: "safari"
                    )
                    
                    InstructionStep(
                        number: "2",
                        title: "Open Developer Tools",
                        description: "Press F12 (Windows/Linux) or Cmd+Option+I (Mac) to open developer tools. Look for tabs called 'Application', 'Storage', or 'Developer Tools' at the top.",
                        icon: "wrench.and.screwdriver"
                    )
                    
                    InstructionStep(
                        number: "3",
                        title: "Navigate to Cookies",
                        description: "In the developer tools panel, look for 'Storage' or 'Application' tab. In the left sidebar, expand 'Cookies' and click on 'https://fantasy.espn.com'.",
                        icon: "list.bullet"
                    )
                    
                    InstructionStep(
                        number: "4",
                        title: "Find and Copy SWID",
                        description: "In the cookies list, find the cookie named 'SWID'. Copy its entire value - it looks like: {ABC-123-DEF-456-GHI}. This is your unique ESPN user identifier.",
                        icon: "doc.on.doc"
                    )
                    
                    InstructionStep(
                        number: "5",
                        title: "Find and Copy espn_s2",
                        description: "Find the cookie named 'espn_s2' and copy its entire value. This is a very long string (200+ characters) with letters, numbers, and symbols like %2F and %3D. Make sure to copy the complete string!",
                        icon: "doc.on.doc.fill"
                    )
                    
                    InstructionStep(
                        number: "6",
                        title: "Find League IDs",
                        description: "Look at your ESPN league URLs. The League ID is the number after 'leagueId='. For example: fantasy.espn.com/football/league?leagueId=1234567890 → League ID is 1234567890",
                        icon: "link"
                    )
                    
                    Divider()
                    
                    // What are these credentials?
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What makes ESPN different from Sleeper?", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("**🔐 SWID**: Your ESPN user ID - uniquely identifies your ESPN account")
                        Text("**🍪 ESPN_S2**: Authentication cookie - proves you're logged in and allows access to private leagues")
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("**📝 MANUAL LEAGUE MANAGEMENT**")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("❌ **ESPN Limitation**: You must manually enter EVERY League ID you want to access")
                        Text("❌ **No Auto-Discovery**: ESPN doesn't provide an API to find all your leagues")
                        Text("📋 **Persistent Storage**: League IDs are saved and remembered between app launches")
                        Text("➕ **Add/Remove**: You can add new leagues or remove old ones anytime")
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("**🆚 Compare with Sleeper:**")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("✅ **Sleeper**: Automatically discovers ALL your leagues")
                        Text("✅ **Zero Setup**: Just username/ID and you're done")
                        Text("✅ **Always Current**: Automatically finds new leagues you join")
                        
                        Text("\n💡 **Recommendation**: Use Sleeper when possible for easier setup!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Important Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Important Security Notes", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("• **Chrome Extension is highly recommended** - much easier and more reliable than manual method")
                        Text("• **Your credentials never leave your device** - stored securely in iOS Keychain")
                        Text("• **Cookies expire periodically** - you may need to update them every few months")
                        Text("• **Only works with leagues you're a member of** - can't access other people's private leagues")
                        Text("• **Read-only access** - BigWarRoom cannot make changes to your ESPN account")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Extension Details
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Chrome Extension Details", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("**Extension Name**: ESPN Cookie Finder")
                        Text("**Developer**: Hashtag Fantasy Sports")
                        Text("**Rating**: 4.4 stars (5 reviews)")
                        Text("**Users**: 1,000+ active users")
                        Text("**Privacy**: Does not collect or store your data")
                        
                        Text("\nTo find it: Open Chrome → Menu (⋮) → Extensions → Chrome Web Store → Search 'ESPN Cookie Finder'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Troubleshooting", systemImage: "wrench.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("**Extension not working?** Make sure you're logged into ESPN and viewing a fantasy league page")
                        Text("**Can't find cookies manually?** Try refreshing the ESPN page and checking developer tools again")
                        Text("**Getting authentication errors?** Your cookies may have expired - get fresh ones")
                        Text("**League not loading?** Verify the League ID is correct and you're a member of that league")
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("ESPN Setup Instructions")
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

// MARK: - Instruction Step Component

struct InstructionStep: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    
                    Text(title)
                        .font(.headline)
                }
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview {
    ESPNSetupView()
}

#Preview("Instructions") {
    ESPNInstructionsSheet()
}