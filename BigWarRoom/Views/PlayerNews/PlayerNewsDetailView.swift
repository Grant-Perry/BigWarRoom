//
//  PlayerNewsDetailView.swift
//  BigWarRoom
//
//  Detailed view for displaying full news article content
//

import SwiftUI

/// Full-screen detail view for displaying complete news article content
struct PlayerNewsDetailView: View {
    let newsItem: PlayerNewsItem
    let playerName: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Article header
                    articleHeader
                    
                    // Main content
                    articleContent
                    
                    // Footer info
                    articleFooter
                }
                .padding()
            }
            .background(newsBackground)
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
    
    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Navigation bar
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                // Share button (future feature)
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .disabled(true) // Disabled for now
            }
            .padding(.top, 8)
            
            // Category and time
            HStack {
                // Category badge
                HStack(spacing: 6) {
                    Image(systemName: newsItem.newsCategory.icon)
                        .font(.system(size: 12, weight: .semibold))
                    
                    Text(newsItem.newsCategory.displayName)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(categoryColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
                
                Spacer()
                
                Text(newsItem.timeAgo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Player name
            Text(playerName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            // Headline
            Text(newsItem.headline)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(nil)
        }
    }
    
    private var articleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description (if available and different from story)
            if let description = newsItem.description,
               !description.isEmpty,
               description != newsItem.story {
                Text(cleanText(description))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            // Main story content
            if let story = newsItem.story, !story.isEmpty {
                Text(cleanText(story))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            } else {
                // Fallback if no story content
                Text("Full article content not available.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
            }
        }
    }
    
    private var articleFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Source and metadata
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Source:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(newsItem.type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack {
                    Text("Published:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(formatPublishedDate(newsItem.publishedDate))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if newsItem.premium {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text("Premium Content")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            // Bottom spacing
            Color.clear
                .frame(height: 20)
        }
    }
    
    // MARK: - Helper Properties & Methods
    
    private var categoryColor: Color {
        switch newsItem.newsCategory {
        case .injury: return .red
        case .practice: return .orange
        case .performance: return .green
        case .general: return .blue
        }
    }
    
    private var newsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.2, green: 0.2, blue: 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private func cleanText(_ text: String) -> String {
        // Remove HTML tags and clean up the text
        let cleaned = text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Replace multiple spaces/newlines with single space
        return cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private func formatPublishedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}