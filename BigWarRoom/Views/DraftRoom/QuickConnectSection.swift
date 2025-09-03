import SwiftUI

struct QuickConnectSection: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Binding var selectedYear: String
    @State private var customSleeperInput: String = "" // Don't default to Gp's ID
    @State private var showConnectionSection = false
    
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
            
            // Service logos with more spacing
            HStack(spacing: 25) {
                AppConstants.sleeperLogo
                    .frame(width: 20, height: 20)
                    .shadow(color: .green.opacity(0.3), radius: 2)
                
                if viewModel.allAvailableDrafts.contains(where: { $0.source == .espn }) {
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
            // Sleeper Card
            ConnectionServiceCard(
                logo: AppConstants.sleeperLogo,
                title: "Sleeper Fantasy",
                subtitle: isSleeperConnected ? "✅ Connected" : "Connect to Sleeper",
                isConnected: isSleeperConnected,
                accentColor: .blue,
                action: {
                    if !isSleeperConnected {
                        Task {
                            await viewModel.connectWithUsernameOrID(customSleeperInput, season: selectedYear)
                        }
                    }
                }
            )
            .disabled(customSleeperInput.isEmpty && !isSleeperConnected)
            
            // ESPN Card
            ConnectionServiceCard(
                logo: AppConstants.espnLogo,
                title: "ESPN Fantasy",
                subtitle: isESPNConnected ? "✅ Connected" : "Connect to ESPN",
                isConnected: isESPNConnected,
                accentColor: .orange,
                action: {
                    if !isESPNConnected {
                        Task {
                            AppConstants.ESPNLeagueYear = selectedYear
                            await viewModel.connectToESPNOnly()
                        }
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
                    customSleeperInput = AppConstants.GpSleeperID
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
    
    // MARK: - Computed Properties
    
    private var isSleeperConnected: Bool {
        viewModel.connectionStatus == .connected
    }
    
    private var isESPNConnected: Bool {
        viewModel.allAvailableDrafts.contains(where: { $0.source == .espn })
    }
}

// MARK: - Connection Service Card (Similar to OnBoarding)

struct ConnectionServiceCard<Logo: View>: View {
    let logo: Logo
    let title: String
    let subtitle: String
    let isConnected: Bool
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
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
        .buttonStyle(.plain)
        .disabled(isConnected)
    }
}