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
    let league: UnifiedLeagueManager.LeagueWrapper  // 🔥 NEW: Pass full league for provider creation
    let fantasyViewModel: FantasyViewModel
    // 🔥 PURE DI: Accept AllLivePlayersViewModel as parameter
    let allLivePlayersViewModel: AllLivePlayersViewModel
    
    @State private var selectedIndex: Int = 0
    @State private var selectedMatchupID: FantasyMatchup.ID? = nil
    @State private var isLoadingAllMatchups = false
    @State private var fetchedAllMatchups: [FantasyMatchup] = []
    @State private var isNavigating = false
    @State private var navigatingDirection: NavigationDirection? = nil
    @State private var hasScrolledToInitialPosition = false
    @State private var isLoadingNeighbors = false
    @State private var userHasNavigated = false
    @Environment(\.dismiss) private var dismiss
    
    // FIX: Add animation trigger that actually changes
    @State private var animationTrigger = false
    
    // NEW: Navigation direction enum
    enum NavigationDirection {
        case left, right
    }
    
    // 🔥 PURE DI: Add allLivePlayersViewModel parameter
    init(
        allMatchups: [FantasyMatchup], 
        startingMatchup: FantasyMatchup, 
        leagueName: String, 
        league: UnifiedLeagueManager.LeagueWrapper, 
        fantasyViewModel: FantasyViewModel,
        allLivePlayersViewModel: AllLivePlayersViewModel
    ) {
        self.allMatchups = allMatchups
        self.startingMatchup = startingMatchup
        self.leagueName = leagueName
        self.league = league
        self.fantasyViewModel = fantasyViewModel
        self.allLivePlayersViewModel = allLivePlayersViewModel
        
        DebugPrint(mode: .navigation, "🏈 LEAGUE MATCHUPS INIT:")
        DebugPrint(mode: .navigation, "   Starting matchup ID: \(startingMatchup.id)")
        DebugPrint(mode: .navigation, "   All matchups count: \(allMatchups.count)")
        DebugPrint(mode: .navigation, "   All matchup IDs: \(allMatchups.map { $0.id })")
        
        // Find the starting index of the matchup user tapped
        let startIndex = allMatchups.firstIndex { matchup in
            matchup.id == startingMatchup.id
        } ?? 0
        
        DebugPrint(mode: .navigation, "   Found starting index: \(startIndex)")
        
        self._selectedIndex = State(initialValue: startIndex)
        self._fetchedAllMatchups = State(initialValue: allMatchups)
        self._selectedMatchupID = State(initialValue: startingMatchup.id)
    }
    
    var body: some View {
        ZStack {
            // Background
            ZStack {
                Color.black
                Image("BG7")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
            }
            .ignoresSafeArea(.all)

            // --- EXIT BUTTON FIX ---
            // Absolute top-left overlay (never covered by long league names)
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Text("Exit")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 14)
                    .padding(.top, 10)
                    Spacer()
                }
                Spacer()
            }
            .zIndex(999) // Highest overlay

            // Main content with ScrollView/tab stuff
            VStack(spacing: 0) {
                Color.clear.frame(height: 100)
                
                paginatedScrollView
                    .overlay(
                        Group {
                            if isLoadingAllMatchups {
                                Color.black.opacity(0.55)
                                    .ignoresSafeArea(.all)
                                    .overlay(
                                        VStack(spacing: 12) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .gpGreen))
                                                .scaleEffect(2.0)
                                            Text("Loading Matchups...")
                                                .font(.system(size: 22, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                    )
                            }
                            
                            if isNavigating {
                                Color.black.opacity(0.55)
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

            // OVERLAY: Centered title section
            VStack {
                VStack(spacing: 4) {
                    Text(leagueName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    
                    if isLoadingAllMatchups {
                        Text("Loading Matchups...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gpGreen.opacity(0.7))
                            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    } else if isLoadingNeighbors {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading other matchups...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gpGreen.opacity(0.6))
                        }
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    } else {
                        Text("Matchup \(currentMatchupPosition) of \(displayMatchups.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gpGreen)
                            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.top, 50)
                
                Spacer()
            }
            
            // OVERLAY: Navigation arrows (left and right edges)
            HStack {
                // Previous matchup button
                if !isLoadingAllMatchups && hasPreviousMatchup {
                    Button(action: {
                        userHasNavigated = true  // 🔥 FIX: Mark user navigation
                        isNavigating = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if let prevID = previousMatchupID {
                                selectedMatchupID = prevID
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 16)
                } else {
                    Spacer()
                        .frame(width: 76)
                }
                
                Spacer()
                
                // Next matchup button
                if !isLoadingAllMatchups && hasNextMatchup {
                    Button(action: {
                        userHasNavigated = true  // 🔥 FIX: Mark user navigation
                        isNavigating = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if let nextID = nextMatchupID {
                                selectedMatchupID = nextID
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 16)
                } else {
                    Spacer()
                        .frame(width: 76)
                }
            }
            .offset(y: -85) // push the chevron up
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            // 🔥 SMART LAZY LOADING: Show instant, load neighbors in background
            if fetchedAllMatchups.isEmpty {
                // We have no matchups at all - shouldn't happen but handle it
                isLoadingAllMatchups = true
                Task {
                    await fetchAllLeagueMatchups()
                }
            } else if fetchedAllMatchups.count == 1 {
                // 🔥 FIX: Don't show the ScrollView yet - wait for all data
                isLoadingNeighbors = true
                Task {
                    await fetchNeighborMatchupsInBackground()
                }
            } else {
                // We already have all matchups - just show them
                isLoadingAllMatchups = false
            }
        }
        .onChange(of: selectedMatchupID) { _ in
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
            
            VStack(spacing: 32) {
                // 🌟 NEW: Animated orb cluster (from IntelligenceLoadingView)
                animatedOrbCluster
                
                VStack(spacing: 16) {
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
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - 🌟 NEW: Animated Orb Cluster
    
    @State private var pulseAnimation: Bool = false
    @State private var orbRotationAngle: Double = 0
    
    private var animatedOrbCluster: some View {
        ZStack {
            // Background glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gpBlue.opacity(0.3),
                            Color.gpGreen.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // Orbiting orbs
            ForEach(0..<6, id: \.self) { index in
                orbView(for: index)
            }
            
            // Central core orb
            centralOrbView
        }
        .rotationEffect(.degrees(orbRotationAngle))
        .animation(.linear(duration: 6.0).repeatForever(autoreverses: false), value: orbRotationAngle)
        .onAppear {
            pulseAnimation = true
            orbRotationAngle = 360
        }
    }
    
    private func orbView(for index: Int) -> some View {
        let angle = Double(index) * 60.0 // 360/6 = 60 degrees apart
        let radius: CGFloat = 50
        let x = cos(angle * .pi / 180) * radius
        let y = sin(angle * .pi / 180) * radius
        
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orbColor(for: index),
                        orbColor(for: index).opacity(0.6),
                        orbColor(for: index).opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 12
                )
            )
            .frame(width: 16, height: 16)
            .offset(x: x, y: y)
            .scaleEffect(pulseAnimation ? 1.4 : 0.8)
            .animation(
                .easeInOut(duration: 1.2)
                .delay(Double(index) * 0.15)
                .repeatForever(autoreverses: true),
                value: pulseAnimation
            )
            .shadow(color: orbColor(for: index), radius: 8, x: 0, y: 0)
    }
    
    private var centralOrbView: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color.gpBlue.opacity(0.8),
                        Color.gpGreen.opacity(0.6),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 5,
                    endRadius: 20
                )
            )
            .frame(width: 32, height: 32)
            .scaleEffect(pulseAnimation ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
            .shadow(color: .white, radius: 12, x: 0, y: 0)
    }
    
    private func orbColor(for index: Int) -> Color {
        let colors: [Color] = [
            .gpBlue, .gpGreen, .gpYellow, .gpRedPink, .purple, .orange
        ]
        return colors[index % colors.count]
    }
    
    // MARK: - Main Tab View
    
    // NEW: Paginated ScrollView with peek effect (Paul Hudson style!)
    private var paginatedScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(displayMatchups.enumerated()), id: \.element.id) { index, matchup in
                        FantasyMatchupDetailView(
                            matchup: matchup,
                            fantasyViewModel: fantasyViewModel,
                            leagueName: leagueName,
                            livePlayersViewModel: allLivePlayersViewModel
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(matchup.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectedMatchupID, anchor: .center)
            .onChange(of: isLoadingAllMatchups) { oldValue, newValue in
                if oldValue == true && newValue == false && !hasScrolledToInitialPosition {
                    if let targetID = selectedMatchupID {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(targetID, anchor: .center)
                            }
                            hasScrolledToInitialPosition = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayMatchups: [FantasyMatchup] {
        return fetchedAllMatchups.isEmpty ? allMatchups : fetchedAllMatchups
    }
    
    private var currentMatchupIndex: Int {
        guard let id = selectedMatchupID,
              let idx = displayMatchups.firstIndex(where: { $0.id == id }) else {
            return 0
        }
        return idx
    }
    
    private var currentMatchupPosition: Int {
        // For user-friendly "Matchup X of Y" (1-based)
        return currentMatchupIndex + 1
    }
    
    private var hasPreviousMatchup: Bool {
        currentMatchupIndex > 0
    }
    private var previousMatchupID: FantasyMatchup.ID? {
        guard hasPreviousMatchup else { return nil }
        return displayMatchups[currentMatchupIndex - 1].id
    }
    private var hasNextMatchup: Bool {
        currentMatchupIndex < displayMatchups.count - 1
    }
    private var nextMatchupID: FantasyMatchup.ID? {
        guard hasNextMatchup else { return nil }
        return displayMatchups[currentMatchupIndex + 1].id
    }
    
    // MARK: - Data Fetching
    
    /// 🔥 NEW: Fetch neighbor matchups in background without blocking UI
    private func fetchNeighborMatchupsInBackground() async {
        let currentWeek = NFLWeekService.shared.currentWeek
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        let provider = LeagueMatchupProvider(
            league: league,
            week: currentWeek,
            year: currentYear
        )

        do {
            let allLeagueMatchups = try await provider.fetchMatchups()
            
            DebugPrint(mode: .navigation, "🏈 NEIGHBOR LOAD COMPLETE:")
            DebugPrint(mode: .navigation, "   Starting matchup ID: \(startingMatchup.id)")
            DebugPrint(mode: .navigation, "   Fetched \(allLeagueMatchups.count) matchups")
            DebugPrint(mode: .navigation, "   Fetched IDs (before sort): \(allLeagueMatchups.map { $0.id })")
            
            // 🔥 FIX: Sort so starting matchup is always first
            let sortedMatchups = allLeagueMatchups.sorted { matchup1, matchup2 in
                if matchup1.id == startingMatchup.id {
                    return true // Starting matchup comes first
                } else if matchup2.id == startingMatchup.id {
                    return false // Starting matchup comes first
                } else {
                    return matchup1.id < matchup2.id // Stable sort for others
                }
            }
            
            DebugPrint(mode: .navigation, "   Fetched IDs (after sort): \(sortedMatchups.map { $0.id })")
            
            await MainActor.run {
                // Update with sorted matchups - starting matchup stays at index 0
                fetchedAllMatchups = sortedMatchups
                
                DebugPrint(mode: .navigation, "🏈 UPDATE COMPLETE:")
                DebugPrint(mode: .navigation, "   selectedMatchupID: \(selectedMatchupID ?? "nil")")
                DebugPrint(mode: .navigation, "   displayMatchups count: \(displayMatchups.count)")
                DebugPrint(mode: .navigation, "   Position: \(currentMatchupPosition) of \(displayMatchups.count)")
                
                isLoadingNeighbors = false
            }
        } catch {
            DebugPrint(mode: .navigation, "❌ NEIGHBOR LOAD FAILED: \(error)")
            await MainActor.run {
                isLoadingNeighbors = false
            }
        }
    }
    
    /// Fetch all matchups for the current league and week
    private func fetchAllLeagueMatchups() async {
        // 🔥 FIX: Always set loading state to false, even on early return
        defer {
            Task { @MainActor in
                isLoadingAllMatchups = false
            }
        }
        
        // 🔥 FIX: Use passed-in league directly instead of selectedLeague
        isLoadingAllMatchups = true
        let currentWeek = NFLWeekService.shared.currentWeek
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        let provider = LeagueMatchupProvider(
            league: league,  // 🔥 Use passed-in league
            week: currentWeek,
            year: currentYear
        )

        do {
            let allLeagueMatchups = try await provider.fetchMatchups()
            await MainActor.run {
                fetchedAllMatchups = allLeagueMatchups

                // 🔥 FIX: Only set selectedMatchupID on initial full load when needed
                // Don't override if user has already navigated
                if !userHasNavigated && selectedMatchupID == nil {
                    // Only set if we don't have a selection yet
                    if allLeagueMatchups.contains(where: { $0.id == startingMatchup.id }) {
                        selectedMatchupID = startingMatchup.id
                    } else if let first = allLeagueMatchups.first {
                        selectedMatchupID = first.id
                    }
                }
            }
        } catch {
            print("❌ LeagueMatchupsTabView: Failed to fetch matchups: \(error)")
            await MainActor.run {
                // Fall back to the passed-in starting matchup
                fetchedAllMatchups = [startingMatchup]
                if !userHasNavigated && selectedMatchupID == nil {
                    selectedMatchupID = startingMatchup.id
                }
            }
        }
    }
}