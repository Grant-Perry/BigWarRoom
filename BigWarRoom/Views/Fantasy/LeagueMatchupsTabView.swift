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
    @State private var selectedMatchupID: FantasyMatchup.ID? = nil
    @State private var isLoadingAllMatchups = false
    @State private var fetchedAllMatchups: [FantasyMatchup] = []
    @State private var isNavigating = false
    @State private var navigatingDirection: NavigationDirection? = nil
    @State private var hasScrolledToInitialPosition = false
    @Environment(\.dismiss) private var dismiss
    
    // FIX: Add animation trigger that actually changes
    @State private var animationTrigger = false
    
    // NEW: Navigation direction enum
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
                                // Show loading overlay OVER the scroll view instead of replacing it
                                Color.black.opacity(0.55)
                                    .ignoresSafeArea(.all)
                                    .overlay(
                                        VStack(spacing: 12) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .gpGreen))
                                                .scaleEffect(2.0)
                                            Text("Loading matchups...")
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
                        Text("Loading matchups...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gpGreen.opacity(0.7))
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
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            isLoadingAllMatchups = true
            animationTrigger.toggle()
            
            Task {
                await fetchAllLeagueMatchups()
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
                            livePlayersViewModel: AllLivePlayersViewModel.shared
                        )
                        .containerRelativeFrame(.horizontal) // Fill container width minus margins
                        .id(matchup.id) // For programmatic scrolling (use the ID)
                    }
                }
                .scrollTargetLayout() // Tell ScrollView to snap to these children
            }
            .scrollTargetBehavior(.viewAligned) // Snap to views, not pages
            .contentMargins(.horizontal, 20, for: .scrollContent) // Create peek spacing
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectedMatchupID, anchor: .center) // Bind to matchup ID with center anchor!
            .onChange(of: isLoadingAllMatchups) { oldValue, newValue in
                // When loading completes and we haven't scrolled yet, force scroll to starting matchup
                if oldValue == true && newValue == false && !hasScrolledToInitialPosition {
                    if let targetID = selectedMatchupID {
                        // Delay to ensure ScrollView is fully laid out
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
    
    /// Fetch all matchups for the current league and week
    private func fetchAllLeagueMatchups() async {
        guard let selectedLeague = fantasyViewModel.selectedLeague else {
            return
        }
        
        isLoadingAllMatchups = true
        let currentWeek = NFLWeekService.shared.currentWeek
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        let provider = LeagueMatchupProvider(
            league: selectedLeague,
            week: currentWeek,
            year: currentYear
        )

        do {
            let allLeagueMatchups = try await provider.fetchMatchups()
            await MainActor.run {
                fetchedAllMatchups = allLeagueMatchups

                // --- MATCHUP SELECTION FIX ---
                // Preserve the starting matchup ID so scroll position works
                if allLeagueMatchups.contains(where: { $0.id == startingMatchup.id }) {
                    selectedMatchupID = startingMatchup.id
                } else if let first = allLeagueMatchups.first {
                    selectedMatchupID = first.id
                } else {
                    selectedMatchupID = nil
                }

                isLoadingAllMatchups = false
            }
        } catch {
            await MainActor.run {
                fetchedAllMatchups = [startingMatchup]
                selectedMatchupID = startingMatchup.id
                isLoadingAllMatchups = false
            }
        }
    }
}