import Foundation
import Combine

/// Protocol for managing all draft connection and authentication functionality
@MainActor
protocol DraftConnectionCoordinator: ObservableObject {
    var connectionStatus: ConnectionStatus { get }
    var sleeperDisplayName: String { get }
    var sleeperUsername: String { get }
    var currentUserID: String? { get }
    var allAvailableDrafts: [UnifiedLeagueManager.LeagueWrapper] { get }
    
    func connectWithUsernameOrID(_ input: String, season: String) async
    func connectToESPNOnly() async
    func connectWithUserID(_ userID: String, season: String) async
    func disconnectFromLive()
    func refreshAllLeagues(season: String) async
    func debugESPNConnection() async
}

/// Concrete implementation of DraftConnectionCoordinator
@MainActor
final class DefaultDraftConnectionCoordinator: DraftConnectionCoordinator {
    
    // MARK: - Published Properties
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var sleeperDisplayName: String = ""
    @Published var sleeperUsername: String = ""
    @Published var allAvailableDrafts: [UnifiedLeagueManager.LeagueWrapper] = []
    
    // MARK: - Internal Properties
    var currentUserID: String?
    
    // 🔥 PHASE 2.5: Inject dependencies instead of using .shared
    private let sleeperClient: SleeperAPIClient
    private let espnClient: ESPNAPIClient
    private let leagueManager: UnifiedLeagueManager
    private let espnCredentials: ESPNCredentialsManager
    
    // MARK: - Delegate
    weak var delegate: DraftConnectionCoordinatorDelegate?
    
    // 🔥 PHASE 2.5: Dependency injection initializer
    init(
        sleeperClient: SleeperAPIClient,
        espnClient: ESPNAPIClient,
        leagueManager: UnifiedLeagueManager,
        espnCredentials: ESPNCredentialsManager
    ) {
        self.sleeperClient = sleeperClient
        self.espnClient = espnClient
        self.leagueManager = leagueManager
        self.espnCredentials = espnCredentials
    }
    
    // MARK: - Connection Methods
    
    func connectWithUsernameOrID(_ input: String, season: String = "2025") async {
        AppLogger.info("Starting connection with input '\(input)', season: \(season)", category: "DraftConnection")

        do {
            let user: SleeperUser
            if input.allSatisfy(\.isNumber) && input.count > 10 {
                user = try await sleeperClient.fetchUserByID(userID: input)
                currentUserID = input
                AppLogger.info("Connected using User ID: \(input)", category: "DraftConnection")
            } else {
                user = try await sleeperClient.fetchUser(username: input)
                currentUserID = user.userID
                AppLogger.info("Connected using username: \(input) -> User ID: \(user.userID)", category: "DraftConnection")
            }

            sleeperDisplayName = user.displayName ?? user.username ?? "Unknown User"
            sleeperUsername = user.username ?? "unknown"

            // Fetch just Sleeper leagues, do not overwrite the whole array!
            await leagueManager.fetchSleeperLeagues(userID: user.userID, season: season)
            // Remove existing Sleeper leagues, append latest, keep other services
            let newSleeperLeagues = leagueManager.allLeagues.filter { $0.source == .sleeper }
            allAvailableDrafts.removeAll { $0.source == .sleeper }
            allAvailableDrafts.append(contentsOf: newSleeperLeagues)

            AppLogger.info("Loaded Sleeper leagues (\(newSleeperLeagues.count)). All available drafts: \(allAvailableDrafts.count)", category: "DraftConnection")
            connectionStatus = .connected
            
            // Notify delegate
            delegate?.connectionCoordinator(self, didConnectWithLeagues: newSleeperLeagues)
            
        } catch {
            AppLogger.error("Connection failed for input '\(input)': \(error)", category: "DraftConnection")
            delegate?.connectionCoordinator(self, didFailWithError: error)
        }
    }

    func connectToESPNOnly() async {
        AppLogger.info("Starting ESPN-only connection", category: "DraftConnection")

        guard espnCredentials.hasValidCredentials else {
            AppLogger.warning("No valid ESPN credentials available", category: "DraftConnection")
            return
        }
        
        // Fetch just ESPN leagues!
        await leagueManager.fetchESPNLeagues()
        let newESPNLeagues = leagueManager.allLeagues.filter { $0.source == .espn }
        allAvailableDrafts.removeAll { $0.source == .espn }
        allAvailableDrafts.append(contentsOf: newESPNLeagues)

        if let swid = espnCredentials.getSWID() {
            currentUserID = swid
        }

        if !newESPNLeagues.isEmpty {
            connectionStatus = .connected
            AppLogger.info("ESPN-only connection complete - Found \(newESPNLeagues.count) ESPN leagues", category: "DraftConnection")
            delegate?.connectionCoordinator(self, didConnectWithLeagues: newESPNLeagues)
        }
    }

    func connectWithUserID(_ userID: String, season: String = "2025") async {
        await connectWithUsernameOrID(userID, season: season)
    }

    func disconnectFromLive() {
        AppLogger.info("Disconnecting from live services", category: "DraftConnection")
        
        connectionStatus = .disconnected
        currentUserID = nil
        
        // Clear league manager
        leagueManager.allLeagues.removeAll()
        allAvailableDrafts.removeAll()
        
        // Notify delegate
        delegate?.connectionCoordinatorDidDisconnect(self)
    }
    
    func refreshAllLeagues(season: String = "2025") async {
        AppLogger.info("Refreshing all leagues for season \(season)", category: "DraftConnection")
        await leagueManager.refreshAllLeagues(sleeperUserID: currentUserID, season: season)
        allAvailableDrafts = leagueManager.allLeagues
        AppLogger.info("Refresh complete - \(allAvailableDrafts.count) leagues available", category: "DraftConnection")
        
        delegate?.connectionCoordinator(self, didRefreshLeagues: allAvailableDrafts)
    }
    
    func debugESPNConnection() async {
        guard let testLeagueID = AppConstants.ESPNLeagueID.first else {
            AppLogger.info("No ESPN league IDs configured", category: "DraftConnection")
            return
        }
        await espnClient.debugESPNConnection(leagueID: testLeagueID)
    }
}

// MARK: - Delegate Protocol

@MainActor
protocol DraftConnectionCoordinatorDelegate: AnyObject {
    func connectionCoordinator(_ coordinator: DraftConnectionCoordinator, didConnectWithLeagues leagues: [UnifiedLeagueManager.LeagueWrapper])
    func connectionCoordinator(_ coordinator: DraftConnectionCoordinator, didFailWithError error: Error)
    func connectionCoordinator(_ coordinator: DraftConnectionCoordinator, didRefreshLeagues leagues: [UnifiedLeagueManager.LeagueWrapper])
    func connectionCoordinatorDidDisconnect(_ coordinator: DraftConnectionCoordinator)
}