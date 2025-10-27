import Foundation
import Observation

@Observable
@MainActor
final class PlayerNewsViewModel {
    var newsItems: [PlayerNewsItem] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCategory: NewsCategory? = nil
    
    var filteredNewsItems: [PlayerNewsItem] {
        guard let selectedCategory = selectedCategory else {
            return newsItems
        }
        return newsItems.filter { $0.newsCategory == selectedCategory }
    }
    
    var newsCategories: [NewsCategory] {
        let categories = newsItems.map { $0.newsCategory }
        return Array(Set(categories)).sorted { $0.rawValue < $1.rawValue }
    }
    
    func loadPlayerNews(espnId: Int) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let newsResponse = try await fetchPlayerNews(espnId: espnId)
                newsItems = newsResponse.feed
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func fetchPlayerNews(espnId: Int) async throws -> PlayerNewsResponse {
        let urlString = "https://site.api.espn.com/apis/fantasy/v2/games/ffl/news/players"
        
        guard var urlComponents = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "playerId", value: "\(espnId)"),
            URLQueryItem(name: "limit", value: "10")
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
        }
        
        return try JSONDecoder().decode(PlayerNewsResponse.self, from: data)
    }
}