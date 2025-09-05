import SwiftUI

struct QuickConnectSection: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Binding var selectedYear: String
    @Binding var selectedTab: Int // Add this for navigation
    @State private var customSleeperInput: String = ""
    @State private var showConnectionSection = false
    @State private var manualDraftID: String = ""
    @State private var isConnectingToDraft = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            connectionHeaderView
            
            // Service Cards (like OnBoarding)
            if showConnectionSection || viewModel.connectionStatus != .connected {
                VStack(spacing: 12) {
                    // Year picker
                    yearPickerSection
                    
                    // Service connection cards
                    serviceCardsSection
                    
                    // Sleeper input (only if not connected)
                    if viewModel.connectionStatus != .connected {
                        sleeperInputSection
                    }
                    
                    // Disconnect button (only if connected)
                    if viewModel.connectionStatus == .connected {
                        disconnectSection
                    }
                    
                    manualDraftEntrySection
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.6), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .onAppear {
            // customSleeperInput = AppConstants.GpSleeperID
        }
    }
    
    private var connectionHeaderView: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showConnectionSection.toggle()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connection")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if viewModel.connectionStatus == .connected {
                        connectionStatusView
                    } else {
                        Text("Connect to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Text(selectedYear)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    
                    Image(systemName: showConnectionSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var connectionStatusView: some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                
                Text("Connected.")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            // Service logos - only show logos for services that actually have leagues
            HStack(spacing: 25) {
                // Show Sleeper logo only if we have Sleeper leagues
                if viewModel.allAvailableDrafts.contains(where: { $0.source == .sleeper }) {
                    AppConstants.sleeperLogo
                        .frame(width: 20, height: 20)
                        .shadow(color: .green.opacity(0.3), radius: 2)
                }
                
                // Show ESPN logo only if we have ESPN leagues
                if viewModel.connectionStatus == .connected && viewModel.allAvailableDrafts.contains(where: { $0.source == .espn }) {
                    AppConstants.espnLogo
                        .frame(width: 20, height: 20)
                        .shadow(color: .green.opacity(0.3), radius: 2)
                }
            }
        }
    }
    
    private var yearPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Season Year")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Picker("Season Year", selection: $selectedYear) {
                ForEach(AppConstants.availableYears, id: \.self) { year in
                    Text(year).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedYear) { _, newYear in
                AppConstants.ESPNLeagueYear = newYear
                
                if viewModel.connectionStatus == .connected {
                    Task {
                        await viewModel.connectWithUsernameOrID(customSleeperInput, season: newYear)
                    }
                }
            }
        }
    }
    
    private var serviceCardsSection: some View {
        VStack(spacing: 12) {
            // Sleeper Card - + button opens credential entry
            ConnectionServiceCard(
                logo: AppConstants.sleeperLogo,
                title: "Sleeper Fantasy",
                subtitle: isSleeperConnected ? "✅ Connected" : "Connect to Sleeper",
                isConnected: isSleeperConnected,
                accentColor: .blue,
                showUseDefault: true,
                action: {
                    // + button action: Navigate to Sleeper setup in Settings
                    // xprint("🔧 Opening Sleeper credential entry")
                    selectedTab = 7 // Navigate to Settings tab (now index 7)
                },
                useDefaultAction: {
                    // Use Default button: Auto-connect with default credentials
                    customSleeperInput = AppConstants.SleeperUser
                    Task {
                        await viewModel.connectWithUsernameOrID(AppConstants.SleeperUser, season: selectedYear)
                    }
                }
            )
            
            // ESPN Card - + button opens credential entry
            ConnectionServiceCard(
                logo: AppConstants.espnLogo,
                title: "ESPN Fantasy", 
                subtitle: isESPNConnected ? "✅ Connected" : "Connect to ESPN",
                isConnected: isESPNConnected,
                accentColor: .orange,
                showUseDefault: true,
                action: {
                    // + button action: Navigate to ESPN setup in Settings
                    // xprint("🔧 Opening ESPN credential entry")
                    selectedTab = 7 // Navigate to Settings tab (now index 7)
                },
                useDefaultAction: {
                    // Use Default button: Auto-connect with default ESPN credentials
                    Task {
                        // Fill default ESPN credentials first
                        ESPNCredentialsManager.shared.saveCredentials(
                            swid: AppConstants.SWID,
                            espnS2: AppConstants.ESPN_S2,
                            leagueIDs: AppConstants.ESPNLeagueID
                        )
                        
                        AppConstants.ESPNLeagueYear = selectedYear
                        await viewModel.connectToESPNOnly()
                    }
                }
            )
        }
    }
    
    private var sleeperInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleeper Username/ID")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                TextField("e.g. 'gpick' or user ID", text: $customSleeperInput)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                
                Button("Use Default") {
                    customSleeperInput = AppConstants.SleeperUser
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    private var disconnectSection: some View {
        Button("Disconnect All Services") {
            viewModel.disconnectFromLive()
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Methods
    
    private func getSleeperCredentialOrPrompt() -> String {
        // Check if user has saved Sleeper credentials
        let sleeperManager = SleeperCredentialsManager.shared
        if let identifier = sleeperManager.getUserIdentifier() {
            customSleeperInput = identifier
            return identifier
        }
        
        // If no saved credentials, use default username
        return AppConstants.SleeperUser
    }
    
    // MARK: - Computed Properties
    
    private var isSleeperConnected: Bool {
        // Check if we actually have Sleeper leagues loaded (not just general connection status)
        return viewModel.allAvailableDrafts.contains(where: { $0.source == .sleeper })
    }
    
    private var isESPNConnected: Bool {
        viewModel.allAvailableDrafts.contains(where: { $0.source == .espn })
    }
    
    private var manualDraftEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Manual Draft ID")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 8) {
                TextField("Enter any draft ID", text: $manualDraftID)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .disabled(isConnectingToDraft)
                
                Button(isConnectingToDraft ? "..." : "Connect") {
                    Task {
                        isConnectingToDraft = true
                        await viewModel.connectToManualDraft(draftID: manualDraftID)
                        isConnectingToDraft = false
                    }
                }
                .font(.callout)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(manualDraftID.isEmpty || isConnectingToDraft)
            }
        }
        .padding(.top, 8) // Add some spacing from the sections above
    }
}

// MARK: - Connection Service Card (Similar to OnBoarding)

struct ConnectionServiceCard<Logo: View>: View {
    let logo: Logo
    let title: String
    let subtitle: String
    let isConnected: Bool
    let accentColor: Color
    let showUseDefault: Bool
    let action: () -> Void
    let useDefaultAction: (() -> Void)?
    
    init(logo: Logo, title: String, subtitle: String, isConnected: Bool, accentColor: Color, showUseDefault: Bool = false, action: @escaping () -> Void, useDefaultAction: (() -> Void)? = nil) {
        self.logo = logo
        self.title = title
        self.subtitle = subtitle
        self.isConnected = isConnected
        self.accentColor = accentColor
        self.showUseDefault = showUseDefault
        self.action = action
        self.useDefaultAction = useDefaultAction
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main connection card
            Button(action: action) {
                HStack(spacing: 12) {
                    logo
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(isConnected ? .green : accentColor)
                    }
                    
                    Spacer()
                    
                    if !isConnected {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(accentColor)
                            .font(.title3)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .disabled(isConnected)
            
            // Use Default button (only if not connected and showUseDefault is true)
            if !isConnected && showUseDefault && useDefaultAction != nil {
                Divider()
                
                Button("Use Default (Gp's Account)") {
                    useDefaultAction?()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isConnected ? Color.green.opacity(0.3) : accentColor.opacity(0.2),
                    lineWidth: isConnected ? 2 : 1
                )
        )
    }
}