import SwiftUI

struct PlayerNewsView: View {
    let player: PlayerData
    @State private var viewModel = PlayerNewsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.2, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    playerHeader
                    
                    // Category Filter
                    if !viewModel.newsCategories.isEmpty {
                        categoryFilter
                    }
                    
                    // Content
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(errorMessage)
                    } else if viewModel.filteredNewsItems.isEmpty {
                        emptyStateView
                    } else {
                        newsListView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onAppear {
            if let espnId = player.espnId {
                viewModel.loadPlayerNews(espnId: espnId)
            }
        }
    }
    
    private var playerHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Player Info
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: player.photoUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.fullName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(player.position)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        
                        Text(player.team)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // ESPN ID badge
                if let espnId = player.espnId {
                    VStack(spacing: 2) {
                        Text("ESPN")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.8))
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All button
                CategoryFilterButton(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil,
                    icon: "list.bullet"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedCategory = nil
                    }
                }
                
                // Category buttons
                ForEach(viewModel.newsCategories, id: \.rawValue) { category in
                    CategoryFilterButton(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category,
                        icon: category.icon
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    private var newsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredNewsItems) { newsItem in
                    NewsItemCard(newsItem: newsItem, playerName: player.fullName)
                }
            }
            .padding()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            
            Text("Loading player news...")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("Unable to load news")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                if let espnId = player.espnId {
                    viewModel.loadPlayerNews(espnId: espnId)
                }
            }
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No news available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Check back later for updates")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.white : Color.white.opacity(0.1)
            )
            .foregroundColor(
                isSelected ? Color.black : Color.white
            )
            .clipShape(Capsule())
        }
    }
}

struct NewsItemCard: View {
    let newsItem: PlayerNewsItem
    let playerName: String // NEW: Pass player name for detail view
    
    @State private var showingDetailView = false // NEW: Sheet state
    
    var body: some View {
        Button(action: {
            showingDetailView = true // Show detail sheet instead of broken URL
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Category badge
                    HStack(spacing: 4) {
                        Image(systemName: newsItem.newsCategory.icon)
                            .font(.system(size: 10, weight: .medium))
                        
                        Text(newsItem.newsCategory.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(newsItem.newsCategory))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Time + tap indicator
                    HStack(spacing: 4) {
                        Text(newsItem.timeAgo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Headline
                Text(newsItem.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Story preview (if available)
                if let story = newsItem.story, !story.isEmpty {
                    Text(cleanStoryText(story))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                
                // Source + tap hint
                HStack {
                    Text(newsItem.type.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Text("Tap to read full article")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetailView) {
            PlayerNewsDetailView(newsItem: newsItem, playerName: playerName)
        }
    }
    
    private func cleanStoryText(_ story: String) -> String {
        // Remove HTML tags and clean up the text
        let cleaned = story
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func categoryColor(_ category: NewsCategory) -> Color {
        switch category {
        case .injury: return .red
        case .practice: return .orange
        case .performance: return .green
        case .general: return .blue
        }
    }
}

#Preview {
    PlayerNewsView(player: PlayerData(
        id: "sample",
        fullName: "Josh Allen",
        position: "QB",
        team: "BUF",
        photoUrl: nil,
        espnId: 17102
    ))
}