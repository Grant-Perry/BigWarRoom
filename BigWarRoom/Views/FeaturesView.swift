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
                description: "Real-time matchup tracking across your Sleeper and ESPN leagues. Monitor scores, projections, and win probabilities in one unified dashboard.",
                badge: nil
            )
            
            FeatureCard(
                icon: "chart.bar.fill",
                iconColor: .gpGreen,
                title: "Live Players Tracker",
                description: "Track all your active players with live scoring, performance tiers, and position filtering. See who's crushing it and who's struggling in real-time.",
                badge: nil
            )
            
            FeatureCard(
                icon: "calendar.circle.fill",
                iconColor: .blue,
                title: "NFL Schedule Integration",
                description: "Complete NFL schedule with live scores, game status, and direct links to player matchups. Never miss a game or scoring opportunity.",
                badge: nil
            )
            
            FeatureCard(
                icon: "person.2.fill",
                iconColor: .orange,
                title: "War Room",
                description: "Advanced draft preparation and league management. Research players, track draft picks, and manage your roster strategy.",
                badge: nil
            )
            
            // Advanced Features
            FeatureCard(
                icon: "brain.head.profile",
                iconColor: .purple,
                title: "AI Pick Suggestions",
                description: "Machine learning-powered draft recommendations based on ADP, projections, and league settings. Get the edge on your competition.",
                badge: "SMART"
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
            
            FeatureCard(
                icon: "person.crop.circle",
                iconColor: .gpGreen,
                title: "My Roster Management",
                description: "Comprehensive roster overview with player performance tracking, injury updates, and lineup optimization suggestions.",
                badge: nil
            )
            
            FeatureCard(
                icon: "football",
                iconColor: .brown,
                title: "Fantasy Matchup Analysis",
                description: "Deep-dive into weekly matchups with opponent analysis, strength of schedule, and strategic recommendations for optimal lineups.",
                badge: nil
            )
            
            // Platform Integration
            FeatureCard(
                icon: "icloud.fill",
                iconColor: .gray,
                title: "Multi-Platform Support",
                description: "Seamless integration with ESPN and Sleeper, and other major fantasy platforms. All your leagues in one place.",
                badge: "UNIVERSAL"
            )
            
            FeatureCard(
                icon: "arrow.clockwise.circle.fill",
                iconColor: .gpPostBot,
                title: "Auto-Refresh Scoring",
                description: "Automatic score updates every 15 seconds during games. Never manually refresh again - your data is always current.",
                badge: "AUTO"
            )
            
            FeatureCard(
                icon: "bell.fill",
                iconColor: .yellow,
                title: "Smart Notifications",
                description: "Intelligent alerts for scoring plays, injury updates, and lineup changes. Stay informed without being overwhelmed.",
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
        default: return .gpPostBot
        }
    }
}

#Preview("Features View") {
    FeaturesView()
        .preferredColorScheme(.dark)
}
