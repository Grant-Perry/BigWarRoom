import Foundation

// MARK: - Connection & Authentication
extension DraftRoomViewModel {
    
    /// Connect using either username or User ID (Sleeper only)
    func connectWithUsernameOrID(_ input: String, season: String = "2025") async {
        logInfo("Starting connection with input '\(input)', season: \(season)", category: "DraftRoom")

        do {
            let user: SleeperUser
            if input.allSatisfy(\.isNumber) && input.count > 10 {
                user = try await sleeperClient.fetchUserByID(userID: input)
                currentUserID = input
                logInfo("Connected using User ID: \(input)", category: "DraftRoom")
            } else {
                user = try await sleeperClient.fetchUser(username: input)
                currentUserID = user.userID
                logInfo("Connected using username: \(input) -> User ID: \(user.userID)", category: "DraftRoom")
            }

            sleeperDisplayName = user.displayName ?? user.username ?? "Unknown User"
            sleeperUsername = user.username ?? "unknown"

            // Fetch just Sleeper leagues, do not overwrite the whole array!
            await leagueManager.fetchSleeperLeagues(userID: user.userID, season: season)
            // Remove existing Sleeper leagues, append latest, keep other services
            let newSleeperLeagues = leagueManager.allLeagues.filter { $0.source == .sleeper }
            allAvailableDrafts.removeAll { $0.source == .sleeper }
            allAvailableDrafts.append(contentsOf: newSleeperLeagues )

            logInfo("Loaded Sleeper leagues (\(newSleeperLeagues.count)). All available drafts: \(allAvailableDrafts.count)", category: "DraftRoom")
            connectionStatus = .connected
        } catch {
            logError("Connection failed for input '\(input)': \(error)", category: "DraftRoom")
        }
    }

    /// Connect to ESPN leagues only (without Sleeper account)
    func connectToESPNOnly() async {
        logInfo("Starting ESPN-only connection", category: "DraftRoom")

        guard ESPNCredentialsManager.shared.hasValidCredentials else {
            logWarning("No valid ESPN credentials available", category: "DraftRoom")
            return
        }
        // Fetch just ESPN leagues!
        await leagueManager.fetchESPNLeagues()
        let newESPNLeagues = leagueManager.allLeagues.filter { $0.source == .espn }
        allAvailableDrafts.removeAll { $0.source == .espn }
        allAvailableDrafts.append(contentsOf: newESPNLeagues )

        if let swid = ESPNCredentialsManager.shared.getSWID() {
            currentUserID = swid
        }

        if !newESPNLeagues.isEmpty {
            connectionStatus = .connected
            logInfo("ESPN-only connection complete - Found \(newESPNLeagues.count) ESPN leagues", category: "DraftRoom")
        }
    }

    func connectWithUserID(_ userID: String, season: String = "2025") async {
        await connectWithUsernameOrID(userID, season: season)
    }

    func disconnectFromLive() {
        logInfo("Disconnecting from live services", category: "DraftRoom")
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
        logInfo("Refreshing all leagues for season \(season)", category: "DraftRoom")
        await leagueManager.refreshAllLeagues(sleeperUserID: currentUserID, season: season)
        allAvailableDrafts = leagueManager.allLeagues
        logInfo("Refresh complete - \(allAvailableDrafts.count) leagues available", category: "DraftRoom")
    }
    
    /// Debug ESPN connection (wrapper method for the view)
    func debugESPNConnection() async {
        guard let testLeagueID = AppConstants.ESPNLeagueID.first else {
            logInfo("No ESPN league IDs configured", category: "DraftRoom")
            return
        }
        await ESPNAPIClient.shared.debugESPNConnection(leagueID: testLeagueID)
    }
}