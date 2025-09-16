//
//  SleeperInstructionsSheet.swift
//  BigWarRoom
//
//  Complete instructions sheet for Sleeper setup
//

import SwiftUI

/// Comprehensive instructions sheet for Sleeper setup and configuration
struct SleeperInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Header - Why Sleeper is Easy
                    SleeperAdvantageHeader()
                    
                    // Method 1 - Username (Recommended)
                    UsernameMethodSection()
                    
                    Text("OR")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                    
                    // Method 2 - User ID
                    UserIDMethodSection()
                    
                    Divider()
                    
                    // What's the difference?
                    ComparisonSection()
                    
                    // What can BigWarRoom access?
                    SleeperVsESPNSection()
                    
                    // Important Notes
                    BenefitsSection()
                    
                    // Troubleshooting
                    TroubleshootingSection()
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

// MARK: - Section Components

/// Header explaining Sleeper advantages
private struct SleeperAdvantageHeader: View {
    var body: some View {
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
    }
}

/// Username method instructions
private struct UsernameMethodSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                Text("METHOD 1: USERNAME (RECOMMENDED)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                InstructionStepView(
                    number: "1",
                    title: "Open Sleeper Website",
                    description: "Go to sleeper.com in your web browser and log into your account",
                    icon: "globe"
                )
                
                InstructionStepView(
                    number: "2",
                    title: "View Your Profile",
                    description: "Click on your profile picture or name to go to your profile page",
                    icon: "person.circle"
                )
                
                InstructionStepView(
                    number: "3",
                    title: "Copy Username from URL",
                    description: "Look at the URL in your browser. It will show: sleeper.com/u/YourUsername - copy the 'YourUsername' part (e.g., 'john_doe', 'fantasyguru', etc.)",
                    icon: "link"
                )
            }
        }
    }
}

/// User ID method instructions
private struct UserIDMethodSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.purple)
                Text("METHOD 2: USER ID")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                InstructionStepView(
                    number: "1",
                    title: "Open Sleeper Mobile App",
                    description: "Open the Sleeper app on your phone or tablet",
                    icon: "iphone"
                )
                
                InstructionStepView(
                    number: "2",
                    title: "Go to Settings",
                    description: "Tap your profile picture, then go to Settings → Account",
                    icon: "gearshape.fill"
                )
                
                InstructionStepView(
                    number: "3",
                    title: "Copy User ID",
                    description: "Your User ID is displayed as a long number (e.g., 123456789012345678). Tap to copy it.",
                    icon: "doc.on.doc"
                )
            }
        }
    }
}

/// Comparison section explaining differences
private struct ComparisonSection: View {
    var body: some View {
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
    }
}

/// Sleeper vs ESPN comparison section
private struct SleeperVsESPNSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Why Sleeper is MUCH easier than ESPN", systemImage: "star.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("✅ **Auto-Discovery**: Automatically finds ALL your leagues")
                Text("✅ **Zero League Setup**: No manual League ID entry required")
                Text("✅ **Always Current**: New leagues appear automatically")
                Text("✅ **Live draft data** - real-time picks, your turn notifications")
                Text("✅ **Player information** - stats, projections, availability")
                Text("✅ **Roster data** - your team, other teams in your leagues")
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Text("🆚 **ESPN Comparison:**")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("❌ **ESPN**: Must manually add every League ID")
                Text("❌ **ESPN**: Complex cookie setup that expires")
                Text("❌ **ESPN**: No auto-discovery of leagues")
            }
            
            Text("\n❌ **Cannot make changes** - BigWarRoom is read-only for both services")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
}

/// Benefits section
private struct BenefitsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Why Sleeper is Better", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• **No authentication required** - public API that doesn't need cookies")
                Text("• **Never expires** - set it once and you're done forever")
                Text("• **Real-time updates** - instantly see new picks and league changes")
                Text("• **Works with all leagues** - public and private leagues you're in")
                Text("• **No browser setup** - just username/ID from your profile")
                Text("• **More reliable** - doesn't break when cookies expire")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

/// Troubleshooting section
private struct TroubleshootingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Troubleshooting", systemImage: "wrench.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("**Can't find username?** Look at sleeper.com/u/YourUsername when logged in")
                Text("**User ID not showing?** Update your Sleeper app to the latest version")
                Text("**Validation failing?** Make sure you entered the username exactly (case-sensitive)")
                Text("**No leagues showing?** Ensure you're a member of fantasy football leagues for the selected season")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
}