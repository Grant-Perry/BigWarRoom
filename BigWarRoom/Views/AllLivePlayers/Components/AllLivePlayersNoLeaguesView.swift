//
//  AllLivePlayersNoLeaguesView.swift
//  BigWarRoom
//
//  No leagues connected component for AllLivePlayersEmptyStateView
//

import SwiftUI

/// No leagues connected view component with enhanced visuals and integrated refresh
struct AllLivePlayersNoLeaguesView: View {
    let viewModel: AllLivePlayersViewModel
    @State private var pulseAnimation = false
    @State private var gradientAnimation = false
    
    var body: some View {
        ZStack {
            // 🔥 DRAMATIC GRADIENT BACKGROUND
            buildDramaticBackground()
            
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    // Enhanced loading state
                    buildLoadingState()
                } else {
                    // Enhanced empty state with refresh button
                    buildEmptyState()
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Background Components
    
    @ViewBuilder
    private func buildDramaticBackground() -> some View {
        // Multi-layer gradient background
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(.systemGray6).opacity(0.1),
                    Color.black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay gradient
            RadialGradient(
                colors: [
                    Color.orange.opacity(gradientAnimation ? 0.3 : 0.1),
                    Color.blue.opacity(gradientAnimation ? 0.2 : 0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: gradientAnimation ? 50 : 200,
                endRadius: gradientAnimation ? 400 : 100
            )
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: gradientAnimation)
            
            // Subtle noise texture
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)
        }
    }
    
    // MARK: - Content Components
    
    @ViewBuilder
    private func buildLoadingState() -> some View {
        VStack(spacing: 20) {
            // Enhanced spinning football with pulse effect
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: pulseAnimation ? 100 : 80, height: pulseAnimation ? 100 : 80)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                
                FantasyLoadingIndicator()
                    .scaleEffect(1.3)
            }
            
            VStack(spacing: 12) {
                Text("Connecting to Leagues...")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Searching for your connected leagues")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private func buildEmptyState() -> some View {
        VStack(spacing: 24) {
            // Enhanced connection icon with pulse
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: pulseAnimation ? 90 : 75, height: pulseAnimation ? 90 : 75)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Image(systemName: "link.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 16) {
                Text("Loading Leagues...")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    Text("Connect to your leagues in Mission Control first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("NOTE: If connection cannot be established, re-connect your ESPN/Sleeper accounts in Mission Control.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            
            // Go to Mission Control button - enhanced
            Button(action: {
                // Send notification to switch to Mission Control tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToMissionControl"), object: nil)
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.subheadline)
                    Text("Go to Mission Control")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue)
                        .shadow(color: .blue.opacity(0.2), radius: 4, x: 0, y: 2)
                )
            }
            
            // 🔥 REFRESH BUTTON - Much smaller and less prominent, moved to bottom
            HStack {
                Spacer()
                
                Button(action: {
                    refreshData()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Refresh Data")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6).opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray5).opacity(0.5), lineWidth: 0.5)
                            )
                    )
                }
                
                Spacer()
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - Animation & Actions
    
    private func startAnimations() {
        pulseAnimation = true
        gradientAnimation = true
    }
    
    private func refreshData() {
        Task {
            await viewModel.matchupsHubViewModel.loadAllMatchups()
            await viewModel.loadAllPlayers()
        }
    }
}
