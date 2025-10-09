//
//  OpponentIntelligenceDashboardView.swift
//  BigWarRoom
//
//  Main view for Opponent Intelligence Dashboard (OID)
//

import SwiftUI

/// **Opponent Intelligence Dashboard**
/// 
/// Strategic opponent analysis across all leagues
struct OpponentIntelligenceDashboardView: View {
    @StateObject private var viewModel = OpponentIntelligenceViewModel()
    @StateObject private var watchService = PlayerWatchService.shared
    @State private var showingFilters = false
    @State private var selectedIntelligence: OpponentIntelligence?
    @State private var showingWeekPicker = false
    @State private var showingWatchedPlayers = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView
                
                VStack(spacing: 0) {
                    // Header with stats
                    headerSection
                    
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.opponentIntelligence.isEmpty {
                        emptyStateView
                    } else {
                        // Main content
                        ScrollView {
                            VStack(spacing: 16) {
                                // Strategic recommendations
                                if !viewModel.priorityRecommendations.isEmpty {
                                    recommendationsSection
                                }
                                
                                // Threat matrix
                                threatMatrixSection
                                
                                // Conflict alerts
                                if !viewModel.conflictPlayers.isEmpty {
                                    conflictsSection
                                }
                                
                                // All opponent players
                                opponentPlayersSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100) // Tab bar space
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadOpponentIntelligence()
            }
            .refreshable {
                await viewModel.manualRefresh()
            }
            .onChange(of: viewModel.lastUpdateTime) { _ in
                watchService.updateWatchedPlayerScores(viewModel.allOpponentPlayers)
            }
            .sheet(item: $selectedIntelligence) { intelligence in
                OpponentDetailSheet(intelligence: intelligence)
            }
            .sheet(isPresented: $showingFilters) {
                OpponentFiltersSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingWeekPicker) {
                WeekPickerView(isPresented: $showingWeekPicker)
            }
            .sheet(isPresented: $showingWatchedPlayers) {
                WatchedPlayersSheet(watchService: watchService)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        Image("BG2")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.4)
            .ignoresSafeArea(.all)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Title and controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Intelligence")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(viewModel.getOverallThreatEmoji())
                            .font(.title)
                    }
                    
                    Text("Opponent Analysis • \(viewModel.timeAgo(viewModel.lastUpdateTime))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Filters button
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { showingWatchedPlayers = true }) {
                        ZStack {
                            Image(systemName: "eye.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(watchService.watchCount > 0 ? .gpOrange : .white)
                            
                            // Badge showing watch count
                            if watchService.watchCount > 0 {
                                Text("\(watchService.watchCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(.red))
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    
                    // Refresh button
                    Button(action: { 
                        Task { await viewModel.manualRefresh() }
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Stats overview
            statsOverviewSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private var statsOverviewSection: some View {
        HStack(spacing: 0) {
            StatCardView(
                value: "\(viewModel.totalOpponentsTracked)",
                label: "OPPONENTS",
                color: .blue
            )
            
            // Week picker button - ADDED like Mission Control
            Button(action: { showingWeekPicker = true }) {
                StatCardView(
                    value: "WEEK \(WeekSelectionManager.shared.selectedWeek)",
                    label: "\(viewModel.totalOpponentsTracked) LEAGUES",
                    color: .blue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            StatCardView(
                value: "\(viewModel.totalConflictCount)",
                label: "CONFLICTS",
                color: viewModel.totalConflictCount > 0 ? .orange : .gray
            )
            
            StatCardView(
                value: "\(viewModel.getLosingMatchups().count)",
                label: "LOSING",
                color: viewModel.getLosingMatchups().count > 0 ? .red : .green
            )
        }
        .padding(.horizontal, 8)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🧠 Strategic Insights")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            ForEach(viewModel.priorityRecommendations.prefix(3), id: \.id) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
    
    private var threatMatrixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎯 Threat Matrix")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(viewModel.filteredIntelligence.count) opponents")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredIntelligence) { intelligence in
                    ThreatMatrixCard(intelligence: intelligence) {
                        selectedIntelligence = intelligence
                    }
                }
            }
        }
    }
    
    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⚠️ Player Conflicts")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(viewModel.conflictPlayers.count) conflicts")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.conflictPlayers.prefix(5)) { conflict in
                    ConflictAlertCard(conflict: conflict)
                }
            }
        }
    }
    
    private var opponentPlayersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("👁️ All Opponent Players")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Menu {
                    ForEach(viewModel.availablePositions, id: \.self) { position in
                        Button(position) {
                            viewModel.setPositionFilter(position)
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.selectedPosition)
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredOpponentPlayers.prefix(20)) { player in
                    OpponentPlayerCard(player: player)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Analyzing opponents across leagues...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Opponents Found")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("Connect your leagues in Settings to start tracking opponents")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Supporting Components

/// Individual stat card for header overview
private struct StatCardView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

#Preview("Opponent Intelligence Dashboard") {
    OpponentIntelligenceDashboardView()
        .preferredColorScheme(.dark)
}