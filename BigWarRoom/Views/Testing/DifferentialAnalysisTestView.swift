//
//  DifferentialAnalysisTestView.swift
//  BigWarRoom
//
//  🔬 TEST VIEW FOR DIFFERENTIAL SCORING ANALYSIS
//  Shows how the new baseline comparison system works
//

import SwiftUI

struct DifferentialAnalysisTestView: View {
    @StateObject private var scoringManager = ScoringSettingsManager.shared
    @State private var selectedLeagueID: String = ""
    @State private var testResults: [TestResult] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🔬 Differential Analysis Tester")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Test the new baseline comparison system against ESPN's appliedTotal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // League Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("League Selection")
                            .font(.headline)
                        
                        HStack {
                            TextField("Enter ESPN League ID", text: $selectedLeagueID)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Test League") {
                                testLeague()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedLeagueID.isEmpty || isLoading)
                        }
                        
                        // Quick league buttons
                        HStack {
                            ForEach(AppConstants.ESPNLeagueID, id: \.self) { leagueID in
                                Button(leagueID) {
                                    selectedLeagueID = leagueID
                                    testLeague()
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(12)
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Testing differential analysis...")
                        }
                        .padding()
                    }
                    
                    // Test Results
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Test Results")
                                .font(.headline)
                            
                            ForEach(testResults) { result in
                                TestResultCard(result: result)
                            }
                        }
                    }
                    
                    // Debug Info
                    if !selectedLeagueID.isEmpty {
                        debugInfoSection
                    }
                }
                .padding()
            }
            .navigationTitle("Differential Analysis")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Information")
                .font(.headline)
            
            Button("Print Analysis Details") {
                scoringManager.printDifferentialAnalysisDetails(for: selectedLeagueID)
            }
            .buttonStyle(.bordered)
            
            Button("Print All Scoring Bases") {
                scoringManager.printAllScoringBases()
            }
            .buttonStyle(.bordered)
            
            Button("Run Test Scenarios") {
                scoringManager.testDifferentialAnalysis(for: selectedLeagueID)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func testLeague() {
        guard !selectedLeagueID.isEmpty else { return }
        
        isLoading = true
        testResults.removeAll()
        
        Task {
            do {
                // This would trigger the ESPN API call and differential analysis
                await testDifferentialAnalysisForLeague(selectedLeagueID)
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ Test failed: \(error)")
                }
            }
        }
    }
    
    private func testDifferentialAnalysisForLeague(_ leagueID: String) async {
        // Simulate testing differential analysis
        // In real implementation, this would:
        // 1. Fetch ESPN league data
        // 2. Run differential analysis
        // 3. Test against real player appliedTotals
        // 4. Return validation results
        
        await MainActor.run {
            // Mock results for demonstration
            testResults = [
                TestResult(
                    scenario: "Standard PPR Detection",
                    success: true,
                    details: "Detected PPR league (rec: 1.0), filtered 12 template rules, kept 18 active rules",
                    confidence: "HIGH"
                ),
                TestResult(
                    scenario: "Core Stats Validation", 
                    success: true,
                    details: "Found all core stats: pass_yd, rush_yd, rec, rec_yd, TDs, etc.",
                    confidence: "HIGH"
                ),
                TestResult(
                    scenario: "Template Noise Filtering",
                    success: true, 
                    details: "Filtered out: kick_ret_yd (0.04), qb_hit (0.5), pass_air_yd (0.02)",
                    confidence: "MEDIUM"
                ),
                TestResult(
                    scenario: "Applied Total Validation",
                    success: false,
                    details: "Our calc: 23.8, ESPN: 24.2, Discrepancy: 0.4 pts",
                    confidence: "GOOD"
                )
            ]
        }
    }
}

struct TestResult: Identifiable {
    let id = UUID()
    let scenario: String
    let success: Bool
    let details: String
    let confidence: String
}

struct TestResultCard: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            // Status indicator
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.scenario)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Confidence: \(result.confidence)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(confidenceColor.opacity(0.2))
                    .foregroundColor(confidenceColor)
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var confidenceColor: Color {
        switch result.confidence {
        case "HIGH", "PERFECT": return .green
        case "MEDIUM", "GOOD": return .orange  
        case "LOW", "FAIR": return .red
        default: return .gray
        }
    }
}

#Preview {
    DifferentialAnalysisTestView()
}