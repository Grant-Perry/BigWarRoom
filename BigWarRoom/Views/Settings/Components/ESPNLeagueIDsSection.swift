//
//  ESPNLeagueIDsSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// League IDs management section
struct ESPNLeagueIDsSection: View {
    @Bindable var viewModel: ESPNSetupViewModel
    
    var body: some View {
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
    }
}