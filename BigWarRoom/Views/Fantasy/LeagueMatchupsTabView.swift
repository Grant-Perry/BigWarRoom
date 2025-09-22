//
//  LeagueMatchupsTabView.swift
//  BigWarRoom
//
//  Horizontal scrolling view for all matchups in a league
//

import SwiftUI

/// Horizontal tab view that allows swiping through all matchups in a league
struct LeagueMatchupsTabView: View {
    let allMatchups: [FantasyMatchup]
    let startingMatchup: FantasyMatchup
    let leagueName: String
    let fantasyViewModel: FantasyViewModel
    
    @State private var selectedIndex: Int = 0
    @State private var isLoadingAllMatchups = false
    @State private var fetchedAllMatchups: [FantasyMatchup] = []
    @State private var isNavigating = false // 🔥 NEW: Track navigation state
    @State private var navigatingDirection: NavigationDirection? = nil // 🔥 NEW: Track direction
    @Environment(\.dismiss) private var dismiss
    
    // 🔥 NEW: Navigation direction enum
    enum NavigationDirection {
        case left, right
    }
    
    init(allMatchups: [FantasyMatchup], startingMatchup: FantasyMatchup, leagueName: String, fantasyViewModel: FantasyViewModel) {
        self.allMatchups = allMatchups
        self.startingMatchup = startingMatchup
        self.leagueName = leagueName
        self.fantasyViewModel = fantasyViewModel
        
        // Find the starting index of the matchup user tapped
        let startIndex = allMatchups.firstIndex { matchup in
            matchup.id == startingMatchup.id
        } ?? 0
        
        self._selectedIndex = State(initialValue: startIndex)
        self._fetchedAllMatchups = State(initialValue: allMatchups)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔥 FIX: Header at top of VStack, not floating
            headerView
            
            // Main content with horizontal swiping
            if isLoadingAllMatchups {
                // 🔥 BETTER Loading state with BG8 background
                loadingView
            } else {
                // 🔥 BETTER TabView with improved responsiveness and full width
                mainTabView
                    .overlay(
                        // 🔥 SIMPLE: Just dim and show spinner
                        Group {
                            if isNavigating {
                                Color.black.opacity(0.7)
                                    .ignoresSafeArea(.all)
                                    .overlay(
                                        VStack(spacing: 12) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .gpGreen))
                                                .scaleEffect(2.0)
                                            
                                            Text("Loading next matchup...")
                                                .font(.system(size: 22, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                    )
                            }
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.all)
        .onAppear {
            Task {
                await fetchAllLeagueMatchups()
            }
        }
        .onChange(of: selectedIndex) { _ in
            // Reset after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isNavigating = false
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ZStack {
            // BG8 background
            Image("BG9")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea(.all)
            
            // Dark overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gpGreen))
                    .scaleEffect(2.5)
                
                VStack(spacing: 8) {
                    Text("Loading League Matchups")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Fetching all \(leagueName) matchups...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Main Tab View
    
    private var mainTabView: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(displayMatchups.enumerated()), id: \.element.id) { index, matchup in
                FantasyMatchupDetailView(
                    matchup: matchup,
                    fantasyViewModel: fantasyViewModel,
                    leagueName: leagueName
                )
                .frame(maxWidth: .infinity) // 🔥 FIX: Force full width expansion
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity) // 🔥 FIX: Ensure TabView itself uses full width
        .ignoresSafeArea(.all)
    }
    
    // MARK: - Computed Properties
    
    private var displayMatchups: [FantasyMatchup] {
        return fetchedAllMatchups.isEmpty ? allMatchups : fetchedAllMatchups
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // Left navigation button  
            Button(action: {
                if selectedIndex > 0 {
                    isNavigating = true // Set immediately
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedIndex -= 1
                    }
                } else {
                    dismiss() // 🔥 BACK TO MISSION CONTROL
                }
            }) {
                Image(systemName: selectedIndex > 0 ? "chevron.left" : "xmark") // 🔥 CHANGED: X when at first matchup
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Matchup counter in center
            VStack(spacing: 2) {
                Text(leagueName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if isLoadingAllMatchups {
                    Text("Loading matchups...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gpGreen.opacity(0.7))
                } else {
                    Text("Matchup \(selectedIndex + 1) of \(displayMatchups.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gpGreen)
                }
            }
            
            Spacer()
            
            // Right navigation button
            Button(action: {
                if selectedIndex < displayMatchups.count - 1 {
                    isNavigating = true // Set immediately
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedIndex += 1
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(selectedIndex < displayMatchups.count - 1 ? .white : .white.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .disabled(selectedIndex >= displayMatchups.count - 1)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .ignoresSafeArea(.all, edges: .top)
        )
    }
    
    // MARK: - Navigation Loading Overlay
    
    private var navigationLoadingOverlay: some View {
        ZStack {
            // Semi-transparent background that COVERS EVERYTHING
            Color.black.opacity(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
            
            // Loading indicator in center
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gpGreen))
                    .scaleEffect(1.8)
                
                Text("Loading Matchup...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gpGreen.opacity(0.4), lineWidth: 2)
                    )
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - Data Fetching
    
    /// Fetch all matchups for the current league and week
    private func fetchAllLeagueMatchups() async {
        guard let selectedLeague = fantasyViewModel.selectedLeague else {
            print("🔥 DEBUG: No selected league available")
            return
        }
        
        print("🔥 DEBUG: Fetching all matchups for league: \(selectedLeague.league.name)")
        print("🔥 DEBUG: Current matchups count: \(fantasyViewModel.matchups.count)")
        
        // 🔥 ALWAYS fetch fresh data - don't trust existing matchups count
        // Mission Control only has the user's matchups, we need ALL league matchups
        
        isLoadingAllMatchups = true
        
        // Force a fresh fetch of ALL matchups for this league
        await fantasyViewModel.fetchMatchups()
        
        // Give it a moment to complete the fetch
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            fetchedAllMatchups = fantasyViewModel.matchups
            print("🔥 DEBUG: After fetch: \(fetchedAllMatchups.count) total matchups")
            
            // Update the selected index to point to the correct matchup
            if let newIndex = fetchedAllMatchups.firstIndex(where: { $0.id == startingMatchup.id }) {
                selectedIndex = newIndex
                print("🔥 DEBUG: Updated selectedIndex to \(newIndex)")
            } else {
                print("🔥 DEBUG: ⚠️ Could not find starting matchup in fetched matchups!")
                selectedIndex = 0 // Fallback to first matchup
            }
            
            isLoadingAllMatchups = false
        }
    }
}