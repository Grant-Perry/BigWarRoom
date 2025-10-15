import Foundation
import Combine

@MainActor
class PlayerNewsViewModel: ObservableObject {
    @Published var newsItems: [PlayerNewsItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: NewsCategory? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
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
        print("🗞️ FETCHING NEWS: Starting for ESPN ID \(espnId)")
        
        isLoading = true
        errorMessage = nil
        
        fetchPlayerNews(espnId: espnId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        print("🗞️ ERROR: Failed to load news - \(error)")
                    }
                },
                receiveValue: { [weak self] newsResponse in
                    print("🗞️ SUCCESS: Loaded \(newsResponse.feed.count) news items")
                    self?.newsItems = newsResponse.feed
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func fetchPlayerNews(espnId: Int) -> AnyPublisher<PlayerNewsResponse, Error> {
        let urlString = "https://site.api.espn.com/apis/fantasy/v2/games/ffl/news/players"
        
        guard var urlComponents = URLComponents(string: urlString) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "playerId", value: "\(espnId)"),
            URLQueryItem(name: "limit", value: "10")
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        print("🗞️ API CALL: \(url.absoluteString)")
        
        return URLSession.shared
            .dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    print("🗞️ HTTP STATUS: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        throw URLError(.badServerResponse)
                    }
                }
                return data
            }
            .decode(type: PlayerNewsResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}