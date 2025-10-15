import Foundation

// MARK: - Player News Models
struct PlayerNewsResponse: Codable {
    let timestamp: String
    let status: String
    let resultsLimit: Int
    let resultsCount: Int
    let feed: [PlayerNewsItem]
}

struct PlayerNewsItem: Codable, Identifiable {
    let id: Int
    let nowId: String?
    let contentKey: String?
    let dataSourceIdentifier: String?
    let type: NewsType
    let headline: String
    let description: String?
    let story: String?
    let categorized: String
    let lastModified: String
    let published: String
    let premium: Bool
    let playerId: Int?
    
    // Computed properties for easier use
    var publishedDate: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: published) ?? Date()
    }
    
    var timeAgo: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(publishedDate)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 { // Less than 1 day
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
    
    var newsCategory: NewsCategory {
        let lowercaseHeadline = headline.lowercased()
        let lowercaseStory = (story ?? "").lowercased()
        
        // Check for injury keywords
        if lowercaseHeadline.contains("injury") || lowercaseHeadline.contains("injured") ||
           lowercaseHeadline.contains("hamstring") || lowercaseHeadline.contains("knee") ||
           lowercaseHeadline.contains("ankle") || lowercaseHeadline.contains("shoulder") ||
           lowercaseStory.contains("injury report") || lowercaseStory.contains("injured reserve") {
            return .injury
        }
        
        // Check for practice keywords
        if lowercaseHeadline.contains("practice") || lowercaseHeadline.contains("limited") ||
           lowercaseHeadline.contains("full participant") || lowercaseStory.contains("practice") {
            return .practice
        }
        
        // Check for performance keywords
        if lowercaseHeadline.contains("completed") || lowercaseHeadline.contains("yards") ||
           lowercaseHeadline.contains("touchdown") || lowercaseHeadline.contains("reception") {
            return .performance
        }
        
        // Default to general
        return .general
    }
}

enum NewsType: String, Codable {
    case rotowire = "Rotowire"
    case story = "Story"
    case media = "Media"
    case headlineNews = "HeadlineNews"
}

enum NewsCategory: String, CaseIterable {
    case injury = "injury"
    case practice = "practice"
    case performance = "performance"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .injury: return "Injury"
        case .practice: return "Practice"
        case .performance: return "Performance"
        case .general: return "News"
        }
    }
    
    var color: String {
        switch self {
        case .injury: return "red"
        case .practice: return "orange"
        case .performance: return "green"
        case .general: return "blue"
        }
    }
    
    var icon: String {
        switch self {
        case .injury: return "cross.fill"
        case .practice: return "figure.run"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .general: return "newspaper.fill"
        }
    }
}