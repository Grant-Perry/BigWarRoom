import SwiftUI

struct QuickConnectSection: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @State private var customSleeperInput: String = AppConstants.GpSleeperID
    @State private var showConnectionSection = false
    @Binding var selectedYear: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showConnectionSection.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
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
                    
                    // Chevron indicator
                    Image(systemName: showConnectionSection ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Connection options (only show if expanded)
            if showConnectionSection {
                connectionOptionsView
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var connectionStatusView: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                
                // Show service logos instead of username
                HStack(spacing: 15) {
                    // Always show Sleeper logo if we have any connection (since we connect through Sleeper)
                    AppConstants.sleeperLogo
                        .frame(width: 20, height: 20)
                        .shadow(color: .gpGreen.opacity(0.8), radius: 5)
                        .shadow(color: .gpGreen.opacity(0.6), radius: 10)
                        .shadow(color: .gpGreen.opacity(0.4), radius: 20)
                    Text(" ")
                    // Show ESPN logo if we have ESPN leagues
                    if viewModel.allAvailableDrafts.contains(where: { $0.source == .espn }) {
                        AppConstants.espnLogo
                            .frame(width: 20, height: 20)
                            .shadow(color: .gpGreen.opacity(0.8), radius: 5)
                            .shadow(color: .gpGreen.opacity(0.6), radius: 10)
                            .shadow(color: .gpGreen.opacity(0.4), radius: 20)
                    }
                }
                
                Spacer()
                
                // Current year in bold on the far right
                Text(selectedYear)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var connectionOptionsView: some View {
        VStack(spacing: 12) {
            // Year picker section
            yearPickerSection
            
            // Action buttons row
            actionButtonsRow
            
            // Sleeper ID input (only show if not connected)
            if viewModel.connectionStatus != .connected {
                sleeperInputSection
            }
        }
    }
    
    private var yearPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Season Year")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Picker("Season Year", selection: $selectedYear) {
                ForEach(AppConstants.availableYears, id: \.self) { year in
                    Text(year).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedYear) { newYear in
                // Update AppConstants when year changes
                AppConstants.ESPNLeagueYear = newYear
                
                // Reconnect if already connected to get new year's data
                if viewModel.connectionStatus == .connected {
                    Task {
                        await viewModel.connectWithUsernameOrID(customSleeperInput, season: newYear)
                    }
                }
            }
        }
    }
    
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            if viewModel.connectionStatus == .connected {
                Button("Disconnect") {
                    viewModel.disconnectFromLive()
                }
                .font(.callout)
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Sleeper connection
                Button {
                    Task {
                        await viewModel.connectWithUsernameOrID(customSleeperInput, season: selectedYear)
                    }
                } label: {
                    HStack(spacing: 6) {
                        AppConstants.sleeperLogo
                            .frame(width: 16, height: 16)
                        Text("Connect Sleeper")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(customSleeperInput.isEmpty)
                
                // ESPN connection
                Button {
                    Task { 
                        // Update ESPN year before connecting
                        AppConstants.ESPNLeagueYear = selectedYear
                        await viewModel.connectToESPNOnly() 
                    }
                } label: {
                    HStack(spacing: 6) {
                        AppConstants.espnLogo
                            .frame(width: 16, height: 16)
                        Text("Connect ESPN")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Spacer()
        }
    }
    
    private var sleeperInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AppConstants.sleeperLogo
                    .frame(width: 18, height: 18)
                Text("Sleeper Username/ID")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 8) {
                TextField("e.g. 'gpick' or user ID", text: $customSleeperInput)
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                
                Button("Paste") {
                    if let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        customSleeperInput = clipboardText
                    }
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Button("Use Default (Gp)") {
                    customSleeperInput = AppConstants.GpSleeperID
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}