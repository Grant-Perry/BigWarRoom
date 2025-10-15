import Foundation

// Player data model for news system
struct PlayerData {
    let id: String
    let fullName: String
    let position: String
    let team: String
    let photoUrl: String?
    let espnId: Int?
    
    // Direct initializer
    init(id: String, fullName: String, position: String, team: String, photoUrl: String?, espnId: Int?) {
        self.id = id
        self.fullName = fullName
        self.position = position
        self.team = team
        self.photoUrl = photoUrl
        self.espnId = espnId
    }
}