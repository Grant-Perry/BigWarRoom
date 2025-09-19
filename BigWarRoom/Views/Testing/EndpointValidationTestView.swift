import SwiftUI

struct EndpointValidationTestView: View {
    @State private var validationService = EndpointValidationService()
    @State private var results: [EndpointValidationService.ValidationResult] = []
    @State private var isRunning = false
    
    // Auto-populated from AppConstants
    @State private var sleeperLeagueId = AppConstants.BigBoysLeagueID
    @State private var selectedESPNLeagueIndex = 0
    @State private var espnSWID = AppConstants.SWID
    @State private var espnS2 = AppConstants.ESPN_S2_2025
    
    // Computed property for selected ESPN League ID
    private var selectedESPNLeagueId: String {
        return AppConstants.ESPNLeagueID[selectedESPNLeagueIndex]
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Test Parameters (Auto-Populated from AppConstants)") {
                    // Sleeper League ID
                    HStack {
                        Text("Sleeper League ID:")
                        Spacer()
                        Text(sleeperLeagueId)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    // ESPN League ID Picker
                    Picker("ESPN League", selection: $selectedESPNLeagueIndex) {
                        ForEach(AppConstants.ESPNLeagueID.indices, id: \.self) { index in
                            Text("League \(index + 1): \(AppConstants.ESPNLeagueID[index])")
                                .tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Show selected ESPN credentials (partially masked for security)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("ESPN SWID:")
                            Spacer()
                            Text(maskCredential(espnSWID))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("ESPN S2:")
                            Spacer()
                            Text(maskCredential(espnS2))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section("Current Selection") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Testing Sleeper League:")
                            Spacer()
                            Text(sleeperLeagueId)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("Testing ESPN League:")
                            Spacer()
                            Text(selectedESPNLeagueId)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            Text("Season Year:")
                            Spacer()
                            Text(AppConstants.currentSeasonYear)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section {
                    Button(action: runValidation) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("🚀 Run Endpoint Validation")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isRunning)
                    
                    if !results.isEmpty && !isRunning {
                        Button("🗑 Clear Results") {
                            results = []
                        }
                        .foregroundColor(.red)
                    }
                }
                
                if !results.isEmpty {
                    Section("Validation Results") {
                        ForEach(results.indices, id: \.self) { index in
                            let result = results[index]
                            ResultRowView(result: result, validationService: validationService)
                        }
                    }
                }
            }
            .navigationTitle("Endpoint Validation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func maskCredential(_ credential: String) -> String {
        guard credential.count > 8 else { return "***" }
        let start = credential.prefix(4)
        let end = credential.suffix(4)
        return "\(start)...\(end)"
    }
    
    private func runValidation() {
        Task {
            await MainActor.run {
                isRunning = true
                results = []
            }
            
            let validationResults = await validationService.runComprehensiveValidation(
                sleeperLeagueId: sleeperLeagueId,
                espnLeagueId: selectedESPNLeagueId,
                espnSeason: AppConstants.currentSeasonYear,
                espnSWID: espnSWID,
                espnS2: espnS2
            )
            
            await MainActor.run {
                results = validationResults
                isRunning = false
            }
        }
    }
}

// MARK: - Result Row Component

private struct ResultRowView: View {
    let result: EndpointValidationService.ValidationResult
    let validationService: EndpointValidationService
    
    @State private var showingJSONDetail = false
    @State private var parsedData: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Status and endpoint
            HStack {
                statusIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(endpointName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(result.endpoint)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if result.success && result.data != nil {
                    Button("View Data") {
                        parseResultData()
                        showingJSONDetail = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Error message
            if let error = result.error {
                Text("❌ \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
            
            // Success metrics
            if result.success {
                HStack(spacing: 12) {
                    if let responseTime = result.responseTime {
                        Label("\(String(format: "%.2f", responseTime))s", systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let data = result.data {
                        Label("\(data.count) bytes", systemImage: "doc.text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingJSONDetail) {
            NavigationView {
                ScrollView {
                    Text(parsedData)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                }
                .navigationTitle("API Response")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingJSONDetail = false
                        }
                    }
                }
            }
        }
    }
    
    private var statusIcon: some View {
        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(result.success ? .green : .red)
            .font(.title2)
    }
    
    private var endpointName: String {
        if result.endpoint.contains("sleeper.app") {
            return "Sleeper League"
        } else if result.endpoint.contains("mSettings") {
            return "ESPN Scoring Rules"
        } else if result.endpoint.contains("fantasy.espn.com") {
            return "ESPN League General"
        } else if result.endpoint.contains("scoreboard") {
            return "ESPN NFL Scoreboard"
        } else if result.endpoint.contains("summary") {
            return "ESPN Game Summary"
        } else {
            return "Unknown Endpoint"
        }
    }
    
    private func parseResultData() {
        guard let data = result.data else {
            parsedData = "No data available"
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                parsedData = prettyString
                
                // Add specific parsing results
                if result.endpoint.contains("sleeper.app") {
                    if let scoringSettings = validationService.parseSleeperScoringSettings(from: data) {
                        parsedData = "SLEEPER SCORING SETTINGS FOUND:\n\n\(scoringSettings.keys.sorted().joined(separator: ", "))\n\n" + parsedData
                    }
                } else if result.endpoint.contains("mSettings") {
                    if let scoringSettings = validationService.parseESPNScoringSettings(from: data) {
                        parsedData = "ESPN SCORING SETTINGS FOUND:\n\n\(scoringSettings.keys.sorted().joined(separator: ", "))\n\n" + parsedData
                    }
                } else if result.endpoint.contains("scoreboard") {
                    if let eventIds = validationService.parseESPNScoreboard(from: data) {
                        parsedData = "ESPN GAMES FOUND:\n\n\(eventIds.joined(separator: ", "))\n\n" + parsedData
                    }
                }
            } else {
                parsedData = "Unable to parse response as text"
            }
        } catch {
            parsedData = "JSON parsing error: \(error.localizedDescription)\n\nRaw data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")"
        }
    }
}

#Preview {
    EndpointValidationTestView()
}