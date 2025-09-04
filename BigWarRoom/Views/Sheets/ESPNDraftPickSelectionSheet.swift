import SwiftUI

struct ESPNDraftPickSelectionSheet: View {
    let leagueName: String
    let maxTeams: Int
    let isFantasyMode: Bool // NEW: Determines if this is for Fantasy (week selection) or Draft (position selection)
    let currentWeek: Int // NEW: Current NFL week for Fantasy mode
    @Binding var selectedValue: Int // Changed from selectedPick to selectedValue (position or week)
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void
    
    // MARK: -> AppStorage for persisting values per league
    @AppStorage("draftPosition") private var storedDraftPositions: String = "{}"
    @AppStorage("fantasyWeeks") private var storedFantasyWeeks: String = "{}"
    
    // Computed property to get saved value for this league
    private var savedValue: Int? {
        let storageKey = isFantasyMode ? storedFantasyWeeks : storedDraftPositions
        guard let data = storageKey.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
            return nil
        }
        return values[leagueName]
    }
    
    // Computed properties for dynamic content
    private var title: String {
        isFantasyMode ? "Select Week" : "Select Draft Position"
    }
    
    private var subtitle: String {
        isFantasyMode ? "Choose week to view matchups" : "Choose your draft position to start tracking picks"
    }
    
    private var maxValue: Int {
        isFantasyMode ? 18 : maxTeams
    }
    
    private var gridColumns: Int {
        isFantasyMode ? 6 : min(maxTeams, 4) // More columns for weeks (1-18)
    }
    
    private var buttonSize: CGFloat {
        isFantasyMode ? 45 : 60 // Smaller circles for weeks
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header info
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(leagueName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Value picker grid (positions 1-maxTeams or weeks 1-18)
                ScrollView {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: gridColumns)
                    
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(1...maxValue, id: \.self) { value in
                            Button("\(value)") {
                                selectedValue = value
                            }
                            .font(isFantasyMode ? .system(size: 14, weight: .medium) : .title3)
                            .fontWeight(.medium)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(
                                selectedValue == value ? 
                                Color.blue : Color(.systemGray5)
                            )
                            .foregroundColor(
                                selectedValue == value ? 
                                .white : .primary
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedValue == value ? Color.blue : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                            .overlay(
                                // Show "Current" indicator for current week in Fantasy mode
                                isFantasyMode && value == currentWeek ?
                                VStack {
                                    Spacer()
                                    Text("Current")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.gpGreen)
                                        .padding(.bottom, 2)
                                } : nil
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Show previously selected value if it exists
                if let savedVal = savedValue {
                    Text(isFantasyMode ? 
                         "You previously selected week \(savedVal)" : 
                         "You previously selected position \(savedVal)")
                        .font(.subheadline)
                        .foregroundColor(.gpGreen)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(isFantasyMode ? 
                           "Confirm Week \(selectedValue)" : 
                           "Confirm Position \(selectedValue)") {
                        // Save the selected value to AppStorage before confirming
                        saveValue(selectedValue)
                        onConfirm(selectedValue)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
            .onAppear {
                // Auto-select the appropriate default value
                if let savedVal = savedValue, savedVal <= maxValue {
                    selectedValue = savedVal
                } else if isFantasyMode {
                    // Default to current week for Fantasy mode
                    selectedValue = currentWeek
                }
            }
        }
    }
    
    // MARK: -> Helper Methods
    
    /// Save the selected value for this specific league
    private func saveValue(_ value: Int) {
        let storageKey = isFantasyMode ? "fantasyWeeks" : "draftPosition"
        let currentStorage = isFantasyMode ? storedFantasyWeeks : storedDraftPositions
        
        // Load existing values
        var values: [String: Int] = [:]
        
        if let data = currentStorage.data(using: .utf8),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Int] {
            values = existing
        }
        
        // Update value for this league
        values[leagueName] = value
        
        // Save back to AppStorage
        if let updatedData = try? JSONSerialization.data(withJSONObject: values),
           let updatedString = String(data: updatedData, encoding: .utf8) {
            if isFantasyMode {
                storedFantasyWeeks = updatedString
                NSLog("🏈 Saved fantasy week \(value) for league '\(leagueName)'")
            } else {
                storedDraftPositions = updatedString
                NSLog("🏈 Saved draft position \(value) for league '\(leagueName)'")
            }
        }
    }
}

// MARK: -> Convenience Initializers

extension ESPNDraftPickSelectionSheet {
    /// Initialize for Draft mode (position selection)
    static func forDraft(
        leagueName: String,
        maxTeams: Int,
        selectedPosition: Binding<Int>,
        onConfirm: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) -> ESPNDraftPickSelectionSheet {
        return ESPNDraftPickSelectionSheet(
            leagueName: leagueName,
            maxTeams: maxTeams,
            isFantasyMode: false,
            currentWeek: 1, // Not used in draft mode
            selectedValue: selectedPosition,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    /// Initialize for Fantasy mode (week selection)  
    static func forFantasy(
        leagueName: String,
        currentWeek: Int,
        selectedWeek: Binding<Int>,
        onConfirm: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) -> ESPNDraftPickSelectionSheet {
        return ESPNDraftPickSelectionSheet(
            leagueName: leagueName,
            maxTeams: 18, // Not used in fantasy mode, weeks go 1-18
            isFantasyMode: true,
            currentWeek: currentWeek,
            selectedValue: selectedWeek,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
}