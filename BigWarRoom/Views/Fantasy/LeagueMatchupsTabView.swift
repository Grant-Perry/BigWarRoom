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
    @State private var isNavigating = false
    @State private var navigatingDirection: NavigationDirection? = nil
    @Environment(\.dismiss) private var dismiss
    
    // 🔥 FIX: Add animation trigger that actually changes
    @State private var animationTrigger = false
    
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
        // 🔥 FIX: Use .background() modifier instead of ZStack to avoid layout conflicts
        VStack(spacing: 0) {
            // Header with navigation controls
            headerView
                .zIndex(100)
            
            // Main content
            if isLoadingAllMatchups {
                loadingView
            } else {
                mainTabView
                    .overlay(
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
        // 🔥 FIX: Use background modifier instead of ZStack - this doesn't affect layout
        .background(
            ZStack {
                Color.black
                Image("BG7")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
            }
            .ignoresSafeArea(.all)
        )
        .onAppear {
            // 🔥 FIX: Start loading immediately instead of async delay
            print("🔥 IMMEDIATE: Starting matchup loading process")
            isLoadingAllMatchups = true // Show loading state IMMEDIATELY
            
            // 🔥 FIX: Start animation trigger
            animationTrigger.toggle()
            
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
            // Dark overlay for loading
            Color.black.opacity(0.6)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 28) {
                VStack(spacing: 20) {
                    // Animated progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gpBlue.opacity(0.3), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                AngularGradient(
                                    colors: [.gpBlue, .gpGreen, .gpBlue],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: animationTrigger)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animationTrigger)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Loading League Matchups")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        
                        Text("Fetching all \(leagueName) matchups...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        // Animated status messages
                        VStack(spacing: 6) {
                            Text("🔍 Scanning league data...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gpBlue.opacity(0.9))
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animationTrigger)
                            
                            Text("⚡ Building matchup details...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gpGreen.opacity(0.9))
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0), value: animationTrigger)
                        }
                    }
                    
                    // Loading dots
                    HStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.gpBlue, .gpGreen],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 10, height: 10)
                                .scaleEffect(animationTrigger ? 1.5 : 1.0)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.15),
                                    value: animationTrigger
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Main Tab View
    
    private var mainTabView: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(displayMatchups.enumerated()), id: \.element.id) { index, matchup in
                // 🔥 FIX: Remove background from FantasyMatchupDetailView since we handle it here
                FantasyMatchupDetailView(
                    matchup: matchup,
                    fantasyViewModel: fantasyViewModel,
                    leagueName: leagueName
                )
                .frame(maxWidth: .infinity)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity) // 🔥 FIX: Ensure TabView itself uses full width
        // 🔥 FIX: Don't clip the TabView - let content handle its own boundaries
    }
    
    // MARK: - Computed Properties
    
    private var displayMatchups: [FantasyMatchup] {
        return fetchedAllMatchups.isEmpty ? allMatchups : fetchedAllMatchups
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // 🔥 FIXED: Always show exit button on left
            Button(action: {
                print("🔥 DEBUG: Dismissing to Mission Control from LeagueMatchupsTabView")
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("Exit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Previous matchup button (only show if not first)
            if selectedIndex > 0 {
                Button(action: {
                    isNavigating = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedIndex -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
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
            
            // Next matchup button (only show if not last)
            if selectedIndex < displayMatchups.count - 1 {
                Button(action: {
                    isNavigating = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedIndex += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 44) // Account for safe area
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea(.all, edges: .top)
        )
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