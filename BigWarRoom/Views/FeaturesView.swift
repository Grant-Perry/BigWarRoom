//
//  FeaturesView.swift
//  BigWarRoom
//
//  Comprehensive features overview showcasing all BigWarRoom capabilities
//

import SwiftUI

struct FeaturesView: View {
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                foxStyleBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        headerSection
                        
                        // Features List
                        featuresSection
                    }
                    .padding(.bottom, 100) // Extra space for tab bar
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Background
    private var foxStyleBackground: some View {
        Image("BG2")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.4)
            .ignoresSafeArea(.all)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gpPostBot)
                
                Text("BigWarRoom Features")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text("Your complete fantasy football command center")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.leading, 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 16) {
            // Core Dashboard Features
            FeatureCard(
                icon: "target",
                iconColor: .gpPostBot,
                title: "Mission Control",
                description: "Real-time matchup tracking across your Sleeper and ESPN leagues. Monitor scores, projections, and win probabilities with dynamic color-coded borders and live updates.",
                badge: "LIVE"
            )
            
            FeatureCard(
                icon: "eye.circle.fill",
                iconColor: .purple,
                title: "Intelligence Dashboard",
                description: "Advanced opponent analysis with injury alerts, conflict detection, and strategic recommendations. Get critical player updates with 'FIX' buttons for instant action.",
                badge: "SMART"
            )
            
            FeatureCard(
                icon: "chart.bar.fill",
                iconColor: .gpGreen,
                title: "All Rostered Players",
                description: "Track every player across all your leagues with live scoring, performance tiers, position filtering, and comprehensive search. Sort by score, position, name, or team.",
                badge: "ENHANCED"
            )
            
            FeatureCard(
                icon: "calendar.circle.fill",
                iconColor: .blue,
                title: "NFL Schedule Integration",
                description: "Complete NFL schedule with live scores, game status, team logos, and betting lines. See which of your players are in live games with color-coded indicators.",
                badge: nil
            )
            
            // Advanced Intelligence Features
            FeatureCard(
                icon: "cross.case.fill",
                iconColor: .red,
                title: "Injury Alert System",
                description: "Real-time injury monitoring with beautiful alert cards showing BYE weeks, IR status, OUT/QUESTIONABLE players, and direct links to fix your lineups.",
                badge: "CRITICAL"
            )
            
            FeatureCard(
                icon: "eye.fill",
                iconColor: .gpOrange,
                title: "Player Watch System",
                description: "Watch and track specific players across all leagues with live score updates, performance notifications, and easy management of your watch list.",
                badge: "NEW"
            )
            
            FeatureCard(
                icon: "magnifyingglass.circle.fill",
                iconColor: .gpBlue,
                title: "Advanced Player Search",
                description: "Search all NFL players or just your rostered players with intelligent name matching, position filtering, and instant results from comprehensive player database.",
                badge: "POWERFUL"
            )
            
            FeatureCard(
                icon: "brain.head.profile",
                iconColor: .purple,
                title: "Conflict Detection",
                description: "Automatically detects when you own players facing each other across leagues, calculating net impact and strategic implications for optimal lineup decisions.",
                badge: "SMART"
            )
            
            // Loading and Performance Features
            FeatureCard(
                icon: "circle.hexagongrid.fill",
                iconColor: .cyan,
                title: "Centralized Loading System",
                description: "Beautiful spinning orb loading screens with progress indicators that change color from red to green. All your data loads upfront for instant tab switching.",
                badge: "SMOOTH"
            )
            
            FeatureCard(
                icon: "arrow.clockwise.circle.fill",
                iconColor: .gpGreen,
                title: "Dynamic Refresh Timers",
                description: "Color-changing countdown timers that show when data will refresh. Green when fresh, orange when halfway, red when almost time to update.",
                badge: "VISUAL"
            )
            
            FeatureCard(
                icon: "percent",
                iconColor: .gpGreen,
                title: "Enhanced Win Probabilities",
                description: "Larger, more visible win percentage displays on matchup cards with improved color coding and better contrast for quick assessment.",
                badge: "IMPROVED"
            )
            
            // War Room and Draft Features
            FeatureCard(
                icon: "person.2.fill",
                iconColor: .orange,
                title: "War Room",
                description: "Advanced draft preparation and league management. Research players, track draft picks, and manage your roster strategy with comprehensive tools.",
                badge: nil
            )
            
            FeatureCard(
                icon: "list.bullet.clipboard",
                iconColor: .cyan,
                title: "Interactive Draft Board",
                description: "Visual draft tracking with player rankings, position needs, and real-time pick updates. Follow along with any draft format.",
                badge: nil
            )
            
            FeatureCard(
                icon: "clock.fill",
                iconColor: .red,
                title: "Live Draft Picks",
                description: "Real-time draft pick notifications and updates. Stay on top of every selection as it happens across all your leagues.",
                badge: "LIVE"
            )
            
            // User Experience Features
            FeatureCard(
                icon: "textformat.size",
                iconColor: .blue,
                title: "Responsive Text Scaling",
                description: "Smart text that automatically scales to fit available space with line limits and minimum scale factors. No more text wrapping or cutoff issues.",
                badge: "POLISHED"
            )
            
            FeatureCard(
                icon: "keyboard.fill",
                iconColor: .gray,
                title: "Intelligent Keyboard Handling",
                description: "Search bars that stay properly positioned when keyboard appears, with auto-focus, auto-capitalization disabled, and proper safe area handling.",
                badge: "UX"
            )
            
            FeatureCard(
                icon: "link.circle.fill",
                iconColor: .gpBlue,
                title: "External App Integration",
                description: "Direct 'FIX' buttons that launch Sleeper app or ESPN website to make lineup changes. Seamless integration with your existing fantasy workflow.",
                badge: "INTEGRATION"
            )
            
            // Platform and Technical Features
            FeatureCard(
                icon: "icloud.fill",
                iconColor: .gray,
                title: "Multi-Platform Support",
                description: "Seamless integration with ESPN and Sleeper platforms. All your leagues unified in one place with consistent data presentation.",
                badge: "UNIVERSAL"
            )
            
            FeatureCard(
                icon: "server.rack",
                iconColor: .green,
                title: "Centralized Data Management",
                description: "Single source of truth for all fantasy data with intelligent caching, background updates, and coordinated loading across all app features.",
                badge: "ARCHITECTURE"
            )
            
            FeatureCard(
                icon: "bell.fill",
                iconColor: .yellow,
                title: "Smart Notifications",
                description: "Intelligent alerts for scoring plays, injury updates, and lineup changes. Contextual badges and visual indicators keep you informed without overwhelming.",
                badge: "SMART"
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Feature Card Component
struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Badge
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(getBadgeColor(for: badge))
                            )
                    }
                }
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            iconColor.opacity(0.1),
                            iconColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    private func getBadgeColor(for badge: String) -> Color {
        switch badge {
        case "NEW": return .gpGreen
        case "LIVE": return .red
        case "SMART": return .purple
        case "AUTO": return .blue
        case "UNIVERSAL": return .orange
        case "CRITICAL": return .red
        case "ENHANCED": return .gpGreen
        case "POWERFUL": return .gpBlue
        case "SMOOTH": return .cyan
        case "VISUAL": return .gpOrange
        case "IMPROVED": return .gpGreen
        case "POLISHED": return .blue
        case "UX": return .purple
        case "INTEGRATION": return .gpBlue
        case "ARCHITECTURE": return .green
        default: return .gpPostBot
        }
    }
}

#Preview("Features View") {
    FeaturesView()
        .preferredColorScheme(.dark)
}