import SwiftUI

/// Week state for visual styling and interaction
private enum WeekState {
    case past       // Weeks that have already happened
    case current    // The current week
    case future     // Future weeks (disabled)
    case normal     // For non-fantasy mode
}

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
        isFantasyMode ? validMaxWeek : maxTeams
    }
    
    // MARK: -> Week Validation Properties
    
    /// The maximum week that can be selected (current week + 0 for now, could be +1 if we want to allow next week)
    private var validMaxWeek: Int {
        // Allow up to current week only - no future weeks
        return currentWeek
    }
    
    /// The minimum week that can be selected (Week 1 of current season)
    private var validMinWeek: Int {
        return 1 // Always allow Week 1
    }
    
    /// Check if a week is selectable
    private func isWeekValid(_ week: Int) -> Bool {
        guard isFantasyMode else { return true } // No limits for draft positions
        return week >= validMinWeek && week <= validMaxWeek
    }
    
    /// Get the visual state of a week
    private func getWeekState(_ week: Int) -> WeekState {
        guard isFantasyMode else { return .normal }
        
        if week > currentWeek {
            return .future
        } else if week == currentWeek {
            return .current
        } else {
            return .past
        }
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
                            let weekState = getWeekState(value)
                            let isValidWeek = isWeekValid(value)
                            let isDisabled = isFantasyMode && !isValidWeek
                            
                            Button("\(value)") {
                                if !isDisabled {
                                    selectedValue = value
                                }
                            }
                            .font(isFantasyMode ? .system(size: 14, weight: .medium) : .title3)
                            .fontWeight(.medium)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(
                                selectedValue == value ? 
                                Color.blue : 
                                getBackgroundColor(for: weekState, isDisabled: isDisabled)
                            )
                            .foregroundColor(
                                isDisabled ? .gray.opacity(0.5) :
                                selectedValue == value ? .white : 
                                getForegroundColor(for: weekState)
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedValue == value ? Color.blue : 
                                        getBorderColor(for: weekState, isDisabled: isDisabled),
                                        lineWidth: selectedValue == value ? 3 : 1
                                    )
                            )
                            .overlay(
                                // Show state indicator for weeks in Fantasy mode
                                isFantasyMode ? 
                                getWeekStateOverlay(for: weekState, week: value) : nil
                            )
                            .disabled(isDisabled)
                            .opacity(isDisabled ? 0.4 : 1.0)
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
                
                // Show week constraints info in Fantasy mode
                if isFantasyMode {
                    VStack(spacing: 4) {
                        HStack(spacing: 16) {
                            // Current week info
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.gpGreen)
                                    .frame(width: 8, height: 8)
                                Text("Week \(currentWeek) (Current)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gpGreen)
                            }
                            
                            Spacer()
                            
                            // Future weeks info
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.red.opacity(0.7))
                                Text("Future weeks locked")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        
                        Text("You can view data for Week 1 through Week \(validMaxWeek)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6).opacity(0.5))
                    )
                    .padding(.horizontal)
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
                if let savedVal = savedValue, savedVal <= maxValue, isWeekValid(savedVal) {
                    selectedValue = savedVal
                } else if isFantasyMode {
                    // Default to current week for Fantasy mode (guaranteed to be valid)
                    selectedValue = currentWeek
                }
            }
        }
    }
    
    // MARK: -> Helper Methods
    
    /// Get background color based on week state
    private func getBackgroundColor(for state: WeekState, isDisabled: Bool) -> Color {
        if isDisabled {
            return Color(.systemGray5).opacity(0.3)
        }
        
        switch state {
        case .current:
            return Color.gpGreen.opacity(0.2)
        case .past:
            return Color(.systemGray5)
        case .future:
            return Color.red.opacity(0.1)
        case .normal:
            return Color(.systemGray5)
        }
    }
    
    /// Get foreground color based on week state
    private func getForegroundColor(for state: WeekState) -> Color {
        switch state {
        case .current:
            return .gpGreen
        case .past:
            return .primary
        case .future:
            return .red.opacity(0.6)
        case .normal:
            return .primary
        }
    }
    
    /// Get border color based on week state
    private func getBorderColor(for state: WeekState, isDisabled: Bool) -> Color {
        if isDisabled {
            return .clear
        }
        
        switch state {
        case .current:
            return .gpGreen.opacity(0.6)
        case .past:
            return .clear
        case .future:
            return .red.opacity(0.3)
        case .normal:
            return .clear
        }
    }
    
    /// Get overlay view for week state
    @ViewBuilder
    private func getWeekStateOverlay(for state: WeekState, week: Int) -> some View {
        VStack {
            Spacer()
            
            switch state {
            case .current:
                Text("NOW")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gpGreen)
                    .padding(.bottom, 2)
            case .past:
                Text("PAST")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
            case .future:
                HStack(spacing: 1) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6))
                    Text("FUTURE")
                        .font(.system(size: 6, weight: .bold))
                }
                .foregroundColor(.red.opacity(0.7))
                .padding(.bottom, 2)
            case .normal:
                EmptyView()
            }
        }
    }

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