//
//  AsyncTeamAvatarView.swift
//  BigWarRoom
//
//  Custom avatar view that supports both regular images (PNG/JPG) and SVG files
//

import SwiftUI
import WebKit

/// Avatar view that handles both standard images and SVG files
struct AsyncTeamAvatarView: View {
    let url: URL
    let size: CGFloat
    let fallbackInitials: String
    let isGrayedOut: Bool
    
    init(url: URL, size: CGFloat, fallbackInitials: String, isGrayedOut: Bool = false) {
        self.url = url
        self.size = size
        self.fallbackInitials = fallbackInitials
        self.isGrayedOut = isGrayedOut
    }
    
    init(team: FantasyTeam, size: CGFloat, isGrayedOut: Bool = false) {
        if let avatarURL = team.avatarURL {
            self.url = avatarURL
        } else {
            self.url = URL(string: "about:blank")!
        }
        
        self.size = size
        self.fallbackInitials = team.teamInitials
        self.isGrayedOut = isGrayedOut
    }
    
    var body: some View {
        Group {
            if url.absoluteString.hasSuffix(".svg") {
                // Use WebView for SVG files
                SVGWebImageView(url: url)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .grayscale(isGrayedOut ? 0.5 : 0.0)
                    .opacity(isGrayedOut ? 0.6 : 1.0)
            } else {
                // Use AsyncImage for standard formats
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .grayscale(isGrayedOut ? 0.5 : 0.0)
                            .opacity(isGrayedOut ? 0.6 : 1.0)
                    case .failure, .empty:
                        FallbackAvatar(initials: fallbackInitials, size: size, isGrayedOut: isGrayedOut)
                    @unknown default:
                        FallbackAvatar(initials: fallbackInitials, size: size, isGrayedOut: isGrayedOut)
                    }
                }
            }
        }
    }
}

/// SVG image renderer using WKWebView
struct SVGWebImageView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // 🔥 NEW: Inject CSS to properly scale SVG content
        let css = """
        <style>
            body {
                margin: 0;
                padding: 0;
                display: flex;
                justify-content: center;
                align-items: center;
                width: 100vw;
                height: 100vh;
                overflow: hidden;
            }
            svg {
                max-width: 100%;
                max-height: 100%;
                width: auto;
                height: auto;
            }
        </style>
        """
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(css)
        </head>
        <body>
            <img src="\(url.absoluteString)" style="max-width: 100%; max-height: 100%; object-fit: contain;">
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No need to reload on update - HTML is static
    }
}

/// Fallback avatar with initials
private struct FallbackAvatar: View {
    let initials: String
    let size: CGFloat
    let isGrayedOut: Bool
    
    init(initials: String, size: CGFloat, isGrayedOut: Bool = false) {
        self.initials = initials
        self.size = size
        self.isGrayedOut = isGrayedOut
    }
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(isGrayedOut ? 0.4 : 0.6),
                        Color.gray.opacity(isGrayedOut ? 0.2 : 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundColor(.white.opacity(isGrayedOut ? 0.8 : 1.0))
            )
            .grayscale(isGrayedOut ? 0.5 : 0.0)
    }
}