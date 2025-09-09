import Foundation

// MARK: - Connection & Authentication
extension DraftRoomViewModel {
    
    /// Connect using either username or User ID (Sleeper only)
    func connectWithUsernameOrID(_ input: String, season: String = "2025") async {
        // x// x Print("🚀 DraftRoomViewModel: Starting connection with input '\(input)', season: \(season)")

        do {
            let user: SleeperUser
            if input.allSatisfy(\.isNumber) && input.count > 10 {
                user = try await sleeperClient.fetchUserByID(userID: input)
                currentUserID = input
                // x// x Print("✅ Connected using User ID: \(input)")
            } else {
                user = try await sleeperClient.fetchUser(username: input)
                currentUserID = user.userID
                // x// x Print("✅ Connected using username: \(input) -> User ID: \(user.userID)")
            }

            sleeperDisplayName = user.displayName ?? user.username ?? "Unknown User"
            sleeperUsername = user.username ?? "unknown"

            // x// x Print("🏈 DraftRoomViewModel: User connected - Display: \(sleeperDisplayName), Username: \(sleeperUsername)")

            // Fetch just Sleeper leagues, do not overwrite the whole array!
            await leagueManager.fetchSleeperLeagues(userID: user.userID, season: season)
            // Remove existing Sleeper leagues, append latest, keep other services
            let newSleeperLeagues = leagueManager.allLeagues.filter { $0.source == .sleeper }
            allAvailableDrafts.removeAll { $0.source == .sleeper }
            allAvailableDrafts.append(contentsOf: newSleeperLeagues )

            // x// x Print("🎯 Loaded Sleeper leagues (\(newSleeperLeagues.count)). All available drafts: \(allAvailableDrafts.count)")
            connectionStatus = .connected
        } catch {
            // x// x Print("❌ Connection failed for input '\(input)': \(error)")
            // Do not set to disconnected, so multi-service is possible
        }
    }

    /// Connect to ESPN leagues only (without Sleeper account)
    func connectToESPNOnly() async {
        // x// x Print("🚀 DraftRoomViewModel: Starting ESPN-only connection")

        guard ESPNCredentialsManager.shared.hasValidCredentials else {
            // x// x Print("❌ DraftRoomViewModel: No valid ESPN credentials available")
            return
        }
        // Fetch just ESPN leagues!
        await leagueManager.fetchESPNLeagues()
        let newESPNLeagues = leagueManager.allLeagues.filter { $0.source == .espn }
        allAvailableDrafts.removeAll { $0.source == .espn }
        allAvailableDrafts.append(contentsOf: newESPNLeagues )

        if let swid = ESPNCredentialsManager.shared.getSWID() {
            currentUserID = swid
            // x// x Print("🏈 DraftRoomViewModel: Set currentUserID to saved SWID: \(String(swid.prefix(20)))...")
        }

        if !newESPNLeagues.isEmpty {
            connectionStatus = .connected
            // x// x Print("✅ ESPN-only connection complete - Found \(newESPNLeagues.count) ESPN leagues")
        }
    }

    func connectWithUserID(_ userID: String, season: String = "2025") async {
        await connectWithUsernameOrID(userID, season: season)
    }

    func disconnectFromLive() {
        // x// x Print("🔌 DraftRoomViewModel: Disconnecting from live services")
        polling.stopPolling()
        selectedDraft = nil
        selectedLeagueWrapper = nil
        allDraftPicks = []
        recentLivePicks = []
        connectionStatus = .disconnected
        currentUserID = nil
        _myRosterID = nil
        myDraftSlot = nil
        allLeagueRosters = []
        
        // Reset manual draft state
        isConnectedToManualDraft = false
        manualDraftNeedsPosition = false
        manualDraftInfo = nil
        
        // Clear league manager
        leagueManager.allLeagues.removeAll()
        allAvailableDrafts.removeAll()
        
        // Don't clear roster here - let user keep their manual roster if they want
    }
    
    /// Refresh all available leagues
    func refreshAllLeagues(season: String = "2025") async {
        // x// x Print("🔄 DraftRoomViewModel: Refreshing all leagues for season \(season)")
        await leagueManager.refreshAllLeagues(sleeperUserID: currentUserID, season: season)
        allAvailableDrafts = leagueManager.allLeagues
        // x// x Print("🔄 DraftRoomViewModel: Refresh complete - \(allAvailableDrafts.count) leagues available")
    }
    
    /// Debug ESPN connection (wrapper method for the view)
    func debugESPNConnection() async {
        guard let testLeagueID = AppConstants.ESPNLeagueID.first else {
            // x// x Print("🏈 No ESPN league IDs configured")
            return
        }
        await ESPNAPIClient.shared.debugESPNConnection(leagueID: testLeagueID)
    }
}
