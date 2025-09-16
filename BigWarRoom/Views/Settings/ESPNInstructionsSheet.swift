//
//  ESPNInstructionsSheet.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Instructions sheet for ESPN setup
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