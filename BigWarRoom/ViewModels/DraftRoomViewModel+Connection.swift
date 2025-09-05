import Foundation

// MARK: - Connection & Authentication
extension DraftRoomViewModel {
    
    /// Connect using either username or User ID (Sleeper only)
    func connectWithUsernameOrID(_ input: String, season: String = "2025") async {
        // xprint("🚀 DraftRoomViewModel: Starting connection with input '\(input)', season: \(season)")

        do {
            let user: SleeperUser
            if input.allSatisfy(\.isNumber) && input.count > 10 {
                user = try await sleeperClient.fetchUserByID(userID: input)
                currentUserID = input
                // xprint("✅ Connected using User ID: \(input)")
            } else {
                user = try await sleeperClient.fetchUser(username: input)
                currentUserID = user.userID
                // xprint("✅ Connected using username: \(input) -> User ID: \(user.userID)")
            }

            sleeperDisplayName = user.displayName ?? user.username ?? "Unknown User"
            sleeperUsername = user.username ?? "unknown"

            // xprint("🏈 DraftRoomViewModel: User connected - Display: \(sleeperDisplayName), Username: \(sleeperUsername)")

            // Fetch just Sleeper leagues, do not overwrite the whole array!
            await leagueManager.fetchSleeperLeagues(userID: user.userID, season: season)
            // Remove existing Sleeper leagues, append latest, keep other services
            let newSleeperLeagues = leagueManager.allLeagues.filter { $0.source == .sleeper }
            allAvailableDrafts.removeAll { $0.source == .sleeper }
            allAvailableDrafts.append(contentsOf: newSleeperLeagues )

            // xprint("🎯 Loaded Sleeper leagues (\(newSleeperLeagues.count)). All available drafts: \(allAvailableDrafts.count)")
            connectionStatus = .connected
        } catch {
            // xprint("❌ Connection failed for input '\(input)': \(error)")
            // Do not set to disconnected, so multi-service is possible
        }
    }

    /// Connect to ESPN leagues only (without Sleeper account)
    func connectToESPNOnly() async {
        // xprint("🚀 DraftRoomViewModel: Starting ESPN-only connection")

        guard ESPNCredentialsManager.shared.hasValidCredentials else {
            // xprint("❌ DraftRoomViewModel: No valid ESPN credentials available")
            return
        }
        // Fetch just ESPN leagues!
        await leagueManager.fetchESPNLeagues()
        let newESPNLeagues = leagueManager.allLeagues.filter { $0.source == .espn }
        allAvailableDrafts.removeAll { $0.source == .espn }
        allAvailableDrafts.append(contentsOf: newESPNLeagues )

        if let swid = ESPNCredentialsManager.shared.getSWID() {
            currentUserID = swid
            // xprint("🏈 DraftRoomViewModel: Set currentUserID to saved SWID: \(String(swid.prefix(20)))...")
        }

        if !newESPNLeagues.isEmpty {
            connectionStatus = .connected
            // xprint("✅ ESPN-only connection complete - Found \(newESPNLeagues.count) ESPN leagues")
        }
    }

    func connectWithUserID(_ userID: String, season: String = "2025") async {
        await connectWithUsernameOrID(userID, season: season)
    }

    func disconnectFromLive() {
        // xprint("🔌 DraftRoomViewModel: Disconnecting from live services")
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
        // xprint("🔄 DraftRoomViewModel: Refreshing all leagues for season \(season)")
        await leagueManager.refreshAllLeagues(sleeperUserID: currentUserID, season: season)
        allAvailableDrafts = leagueManager.allLeagues
        // xprint("🔄 DraftRoomViewModel: Refresh complete - \(allAvailableDrafts.count) leagues available")
    }
    
    /// Debug ESPN connection (wrapper method for the view)
    func debugESPNConnection() async {
        guard let testLeagueID = AppConstants.ESPNLeagueID.first else {
            // xprint("🏈 No ESPN league IDs configured")
            return
        }
        await ESPNAPIClient.shared.debugESPNConnection(leagueID: testLeagueID)
    }
}