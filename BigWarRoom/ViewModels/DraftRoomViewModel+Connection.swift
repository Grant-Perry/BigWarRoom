import Foundation

// MARK: - Connection & Authentication
extension DraftRoomViewModel {
    
    /// Connect using either username or User ID (Sleeper only)
    func connectWithUsernameOrID(_ input: String, season: String = "2025") async {
        connectionStatus = .connecting
        
        do {
            let user: SleeperUser
            
            // Try to determine if input is a username or User ID
            if input.allSatisfy(\.isNumber) && input.count > 10 {
                // Looks like a User ID (all numbers, long)
                user = try await sleeperClient.fetchUserByID(userID: input)
                currentUserID = input
                print("✅ Connected using User ID: \(input)")
            } else {
                // Looks like a username
                user = try await sleeperClient.fetchUser(username: input)
                currentUserID = user.userID
                print("✅ Connected using username: \(input) -> User ID: \(user.userID)")
            }
            
            sleeperDisplayName = user.displayName ?? user.username
            sleeperUsername = user.username
            
            // Fetch leagues from both Sleeper and ESPN using the specified season
            await leagueManager.fetchAllLeagues(sleeperUserID: user.userID, season: season)
            allAvailableDrafts = leagueManager.allLeagues
            
            connectionStatus = .connected
            print("🏈 Connected to \(season) season leagues")
        } catch {
            print("❌ Connection failed for input '\(input)': \(error)")
            connectionStatus = .disconnected
        }
    }

    /// Connect to ESPN leagues only (without Sleeper account)
    func connectToESPNOnly() async {
        connectionStatus = .connecting
        
        // Fetch ESPN leagues only
        await leagueManager.fetchESPNLeagues()
        allAvailableDrafts = leagueManager.allLeagues

        sleeperDisplayName = "ESPN User"
        sleeperUsername = "espn_user"
        // Set currentUserID to SWID for ESPN roster matching
        currentUserID = AppConstants.SWID
        connectionStatus = .connected

        print("🏈 Connected to ESPN leagues")
        print("🏈 Set currentUserID to SWID: \(AppConstants.SWID)")
    }

    func connectWithUserID(_ userID: String, season: String = "2025") async {
        await connectWithUsernameOrID(userID, season: season)
    }

    func disconnectFromLive() {
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
        await leagueManager.refreshAllLeagues(sleeperUserID: currentUserID, season: season)
        allAvailableDrafts = leagueManager.allLeagues
    }
    
    /// Debug ESPN connection (wrapper method for the view)
    func debugESPNConnection() async {
        guard let testLeagueID = AppConstants.ESPNLeagueID.first else {
            print("🏈 No ESPN league IDs configured")
            return
        }
        await ESPNAPIClient.shared.debugESPNConnection(leagueID: testLeagueID)
    }
}