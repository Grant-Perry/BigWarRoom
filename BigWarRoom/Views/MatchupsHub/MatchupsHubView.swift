//
   //  MatchupsHubView.swift
   //  BigWarRoom
   //
   //  The ultimate fantasy football command center - your personal war room
   //

import SwiftUI

struct MatchupsHubView: View {
   @StateObject private var viewModel = MatchupsHubViewModel()
   @State private var showingMatchupDetail: UnifiedMatchup?
   @State private var refreshing = false
   @State private var cardAnimationStagger: Double = 0
   @State private var showingSettings = false
   
	  // MARK: -> Micro Mode States
   @State private var microMode = false
   @State private var expandedCardId: String? = nil
   
   // MARK: -> Battles Section State
   @State private var battlesMinimized = false
   
	  // MARK: -> Sorting States
   @State private var sortByWinning = true // true = Win (highest scores first), false = Lose (lowest scores first)
   
	  // MARK: -> Timer States
   @State private var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
   @State private var countdownTimer: Timer?
   
   // MARK: -> Week Picker States
   @State private var selectedWeek: Int = NFLWeekService.shared.currentWeek
   @State private var showingWeekPicker = false

   var body: some View {
	  NavigationView {
		 ZStack {
			   // Background gradient
			backgroundGradient
			
			if viewModel.isLoading && viewModel.myMatchups.isEmpty {
				  // Initial loading state
			   loadingState
			} else if viewModel.myMatchups.isEmpty && !viewModel.isLoading {
				  // Empty state
			   emptyState
			} else {
				  // Matchups content
			   matchupsContent
			}
		 }
		 .navigationTitle("")
		 .navigationBarHidden(true)
		 .onAppear {
			loadInitialData()
			startPeriodicRefresh()
		 }
		 .onDisappear {
			stopPeriodicRefresh()
		 }
		 .refreshable {
			await handlePullToRefresh()
		 }
	  }
	  .sheet(item: $showingMatchupDetail) { matchup in
		 if matchup.isChoppedLeague {
			   // Show chopped league detail view
			if let choppedSummary = matchup.choppedSummary {
			   ChoppedLeaderboardView(
				  choppedSummary: choppedSummary,
				  leagueName: matchup.league.league.name,
				  leagueID: matchup.league.league.leagueID // 🔥 NEW: Pass league ID for roster navigation
			   )
			}
		 } else if let fantasyMatchup = matchup.fantasyMatchup {
			   // Show regular matchup detail view
			let configuredViewModel = matchup.createConfiguredFantasyViewModel()
			FantasyMatchupDetailView(
			   matchup: fantasyMatchup,
			   fantasyViewModel: configuredViewModel,
			   leagueName: matchup.league.league.name
			)
		 }
	  }
	  .sheet(isPresented: $showingSettings) {
		 AppSettingsView()
	  }
	  .sheet(isPresented: $showingWeekPicker) {
		 ESPNDraftPickSelectionSheet.forFantasy(
			leagueName: "Mission Control",
			currentWeek: NFLWeekService.shared.currentWeek,
			selectedWeek: $selectedWeek,
			onConfirm: { week in
			   onWeekSelected(week)
			   showingWeekPicker = false
			},
			onCancel: {
			   showingWeekPicker = false
			}
		 )
	  }
	  .onChange(of: selectedWeek) { oldValue, newValue in
		 if oldValue != newValue {
			onWeekSelected(newValue)
		 }
	  }
   }
   
	  // MARK: -> Background
   
   private var backgroundGradient: some View {
	  LinearGradient(
		 colors: [
			Color.black,
			Color.black.opacity(0.9),
			Color.gpGreen.opacity(0.1),
			Color.black.opacity(0.9),
			Color.black
		 ],
		 startPoint: .topLeading,
		 endPoint: .bottomTrailing
	  )
	  .ignoresSafeArea()
   }
   
	  // MARK: -> Loading State
   
   private var loadingState: some View {
	  VStack {
		 Spacer()
		 
		 MatchupsHubLoadingIndicator(
			currentLeague: viewModel.currentLoadingLeague,
			progress: viewModel.loadingProgress,
			loadingStates: viewModel.loadingStates
		 )
		 
		 Spacer()
	  }
   }
   
	  // MARK: -> Empty State
   
   private var emptyState: some View {
      VStack(spacing: 0) {
         Spacer()
         
         // 🔥 HERO ANIMATION SECTION
         VStack(spacing: 24) {
            // Animated football with particle effects
            ZStack {
               // Outer glow rings (animated with enhanced pulsing)
               ForEach(0..<3) { index in
                  Circle()
                     .stroke(
                        LinearGradient(
                           colors: [.gpGreen.opacity(0.9), .blue.opacity(0.7), .purple.opacity(0.5), .clear],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                     )
                     .frame(width: CGFloat(120 + index * 40), height: CGFloat(120 + index * 40))
                     .opacity(0.6 - Double(index) * 0.15)
                     .scaleEffect(0.8 + sin(Date().timeIntervalSince1970 * 1.5 + Double(index) * 0.8) * 0.3)
                     .rotationEffect(.degrees(Date().timeIntervalSince1970 * 10 + Double(index) * 30))
                     .shadow(color: .gpGreen.opacity(0.4), radius: 8 + CGFloat(index * 4), x: 0, y: 0)
                     .shadow(color: .blue.opacity(0.3), radius: 15 + CGFloat(index * 6), x: 0, y: 0)
                     .animation(.easeInOut(duration: 3 + Double(index) * 0.7).repeatForever(autoreverses: true), value: Date())
               }
               
               // Inner pulsing energy ring
               Circle()
                  .stroke(
                     LinearGradient(
                        colors: [.white.opacity(0.8), .gpGreen, .blue, .white.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                     ),
                     lineWidth: 2
                  )
                  .frame(width: 100, height: 100)
                  .opacity(0.8)
                  .scaleEffect(0.9 + sin(Date().timeIntervalSince1970 * 2.5) * 0.15)
                  .rotationEffect(.degrees(-Date().timeIntervalSince1970 * 15))
                  .shadow(color: .white.opacity(0.6), radius: 12, x: 0, y: 0)
                  .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: Date())
               
               // Central pulsing gradient background (enhanced)
               Circle()
                  .fill(
                     RadialGradient(
                        colors: [
                           .gpGreen.opacity(0.8),
                           .blue.opacity(0.6),
                           .purple.opacity(0.4),
                           .clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 90
                     )
                  )
                  .frame(width: 120, height: 120)
                  .scaleEffect(1.1 + sin(Date().timeIntervalSince1970 * 1.8) * 0.2)
                  .blur(radius: 10)
                  .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: Date())
               
               // Main football icon with glow (fixed position as requested)
               Image(systemName: "football")
                  .font(.system(size: 50, weight: .bold))
                  .foregroundStyle(
                     LinearGradient(
                        colors: [.white, .gpGreen, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                     )
                  )
                  .shadow(color: .gpGreen, radius: 15, x: 0, y: 0)
                  .shadow(color: .blue, radius: 25, x: 0, y: 0)
                  .shadow(color: .white, radius: 8, x: 0, y: 0)
            }
            
            // 🔥 DRAMATIC TEXT SECTION
            VStack(spacing: 16) {
               // Main title with animated gradient
               Text("NO ACTIVE BATTLES")
                  .font(.system(size: 32, weight: .black, design: .rounded))
                  .foregroundStyle(
                     LinearGradient(
                        colors: [.white, .gpGreen, .blue, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                     )
                  )
                  .scaleEffect(1 + sin(Date().timeIntervalSince1970 * 2) * 0.05)
                  .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: Date())
               
               // Subtitle with typewriter effect styling
               VStack(spacing: 8) {
                  Text("Your fantasy leagues are waiting")
                     .font(.system(size: 18, weight: .medium))
                     .foregroundColor(.gray.opacity(0.9))
                  
                  Text("Connect now and dominate the competition")
                     .font(.system(size: 16, weight: .medium))
                     .foregroundStyle(
                        LinearGradient(
                           colors: [.gpGreen.opacity(0.8), .blue.opacity(0.8)],
                           startPoint: .leading,
                           endPoint: .trailing
                        )
                     )
               }
               .multilineTextAlignment(.center)
               .padding(.horizontal, 40)
            }
         }
         
         Spacer()
         
         // 🔥 EPIC CTA BUTTON SECTION
         VStack(spacing: 20) {
            // Floating particles around button area
            ZStack {
               ForEach(0..<6) { index in
                  Circle()
                     .fill(
                        LinearGradient(
                           colors: [.gpGreen, .blue, .purple],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing
                        )
                     )
                     .frame(width: 4, height: 4)
                     .offset(
                        x: cos(Date().timeIntervalSince1970 * 1.5 + Double(index) * 1.047) * 60,
                        y: sin(Date().timeIntervalSince1970 * 1.5 + Double(index) * 1.047) * 30
                     )
                     .opacity(0.7)
                     .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: Date())
               }
               
               // Main CTA button with epic effects
               Button(action: {
                  showingSettings = true
               }) {
                  HStack(spacing: 12) {
                     // Animated plus icon
                     ZStack {
                        Circle()
                           .fill(.white.opacity(0.2))
                           .frame(width: 24, height: 24)
                        
                        Image(systemName: "plus.circle.fill")
                           .font(.system(size: 18, weight: .bold))
                           .foregroundColor(.white)
                           .scaleEffect(1 + sin(Date().timeIntervalSince1970 * 3) * 0.1)
                           .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: Date())
                     }
                     
                     Text("CONNECT LEAGUES")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1)
                     
                     // Animated arrow
                     Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(x: sin(Date().timeIntervalSince1970 * 4) * 3)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: Date())
                  }
                  .padding(.horizontal, 32)
                  .padding(.vertical, 18)
                  .background(
                     ZStack {
                        // Base gradient
                        RoundedRectangle(cornerRadius: 30)
                           .fill(
                              LinearGradient(
                                 colors: [.gpGreen, .blue, .purple],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing
                              )
                           )
                        
                        // Animated shimmer overlay
                        RoundedRectangle(cornerRadius: 30)
                           .stroke(
                              LinearGradient(
                                 colors: [.white.opacity(0.6), .clear, .white.opacity(0.6)],
                                 startPoint: .leading,
                                 endPoint: .trailing
                              ),
                              lineWidth: 2
                           )
                           .offset(x: sin(Date().timeIntervalSince1970 * 2) * 20)
                           .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: Date())
                        
                        // Glow effect
                        RoundedRectangle(cornerRadius: 30)
                           .fill(.clear)
                           .shadow(color: .gpGreen.opacity(0.5), radius: 15, x: 0, y: 0)
                           .shadow(color: .blue.opacity(0.5), radius: 25, x: 0, y: 5)
                     }
                  )
                  .scaleEffect(1 + sin(Date().timeIntervalSince1970 * 2.5) * 0.03)
                  .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: Date())
               }
            }
            .frame(height: 80)
            
            // Subtle hint text
            Text("ESPN • Sleeper • More platforms coming")
               .font(.system(size: 12, weight: .medium))
               .foregroundStyle(
                  LinearGradient(
                     colors: [.gray.opacity(0.8), .gpGreen.opacity(0.6)],
                     startPoint: .leading,
                     endPoint: .trailing
                  )
               )
               .padding(.bottom, 20)
         }
         
         Spacer()
      }
      .background(
         // Animated background particles
         ZStack {
            ForEach(0..<15) { index in
               Circle()
                  .fill(
                     LinearGradient(
                        colors: [.gpGreen.opacity(0.1), .blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                     )
                  )
                  .frame(width: CGFloat.random(in: 2...8), height: CGFloat.random(in: 2...8))
                  .position(
                     x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                     y: CGFloat.random(in: 0...UIScreen.main.bounds.height) + sin(Date().timeIntervalSince1970 * 0.5 + Double(index)) * 50
                  )
                  .animation(.linear(duration: Double.random(in: 8...15)).repeatForever(autoreverses: false), value: Date())
            }
         }
      )
   }
   
	  // MARK: -> Matchups Content
   
   private var matchupsContent: some View {
	  ScrollView(.vertical, showsIndicators: false) {
		 LazyVStack(spacing: 0) {
			   // Hero header
			heroHeader
			
			   // Matchups section
			matchupsSection
			
			   // Bottom padding for tab bar
			Color.clear.frame(height: 100)
		 }
	  }
   }
   
   private var heroHeader: some View {
	  VStack(spacing: 16) {
			// Mission Control title
		 VStack(spacing: 8) {
			HStack {
			   Image(systemName: "target")
				  .font(.system(size: 20, weight: .bold))
				  .foregroundColor(.gpGreen)
			   
			   Text("MISSION CONTROL")
				  .font(.system(size: 28, weight: .black, design: .rounded))
				  .foregroundStyle(
					 LinearGradient(
						colors: [.white, .gpGreen.opacity(0.8)],
						startPoint: .leading,
						endPoint: .trailing
					 )
				  )
			   
			   Image(systemName: "rocket")
				  .font(.system(size: 20, weight: .bold))
				  .foregroundColor(.gpGreen)
			}
			
			Text("Fantasy Football Command Center")
			   .font(.system(size: 14, weight: .medium))
			   .foregroundColor(.gray)
		 }
		 
			// Stats overview
		 statsOverview
		 
			// Last update info
		 lastUpdateInfo
	  }
	  .padding(.horizontal, 20)
	  .padding(.top, 20)
	  .padding(.bottom, 24)
   }
   
   private var statsOverview: some View {
	  HStack(spacing: 0) {
		 statCard(
			value: "\(viewModel.myMatchups.count)",
			label: "MATCHUPS",
			color: .gpGreen
		 )
		 
		 // Make the week stat card tappable to show week picker
		 Button(action: {
			showWeekPicker()
		 }) {
			statCard(
			   value: "WEEK \(selectedWeek)",
			   label: "ACTIVE",
			   color: .blue
			)
		 }
		 .buttonStyle(PlainButtonStyle())
		 
		 statCard(
			value: "\(connectedLeaguesCount)",
			label: "LEAGUES",
			color: .purple
		 )
	  }
	  .padding(.horizontal, 8)
   }
   
   private func statCard(value: String, label: String, color: Color) -> some View {
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
			.fill(color.opacity(0.1))
			.overlay(
			   RoundedRectangle(cornerRadius: 12)
				  .stroke(color.opacity(0.3), lineWidth: 1)
			)
	  )
   }
   
   private var lastUpdateInfo: some View {
	  HStack(spacing: 8) {
		 Image(systemName: "bolt.fill")
			.font(.system(size: 12))
			.foregroundColor(.gpGreen)
		 
		 if let lastUpdate = viewModel.lastUpdateTime {
			Text("Last Update: \(timeAgo(lastUpdate))")
			   .font(.system(size: 12, weight: .medium))
			   .foregroundColor(.gray)
		 } else {
			Text("Ready to load your battles")
			   .font(.system(size: 12, weight: .medium))
			   .foregroundColor(.gray)
		 }
		 
		 Spacer()
		 
			// Auto refresh indicator
		 if viewModel.autoRefreshEnabled {
			HStack(spacing: 4) {
			   Circle()
				  .fill(Color.green)
				  .frame(width: 8, height: 8)
				  .opacity(0.8)
			   
			   Text("Auto-refresh ON")
				  .font(.system(size: 10, weight: .medium))
				  .foregroundColor(.green)
			}
		 }
	  }
	  .padding(.horizontal, 16)
	  .padding(.vertical, 8)
	  .background(
		 RoundedRectangle(cornerRadius: 8)
			.fill(Color.black.opacity(0.3))
	  )
   }
   
   private var matchupsSection: some View {
	  VStack(spacing: 20) {
			// This HStack will contain the title and the micro toggle on the same line
		 HStack {
			   // Group the icon and title text with minimize button
			HStack(spacing: 8) {
			   Button(action: {
				  withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
					 battlesMinimized.toggle()
				  }
			   }) {
				  Image(systemName: battlesMinimized ? "chevron.right" : "chevron.down")
					 .font(.system(size: 14, weight: .bold))
					 .foregroundColor(.white)
					 .frame(width: 20, height: 20)
			   }
			   .buttonStyle(PlainButtonStyle())
			   
			   Image(systemName: "sword.crossed")
				  .font(.system(size: 16, weight: .bold))
				  .foregroundColor(.white)
			   
			   Text("ALL YOUR BATTLES")
				  .font(.system(size: 18, weight: .black))
				  .foregroundColor(.white)
			}
			
			Spacer() // This pushes the next element to the right edge
			
			   // This HStack holds the "Micro:" text and the toggle.
			   // By placing it after the Spacer, it will align to the trailing edge.
			if !battlesMinimized {
			   HStack(spacing: 4) {
				  Text("Just me mode:")
					 .font(.system(size: 14, weight: .bold))
					 .foregroundColor(.gray)
				  
				  Toggle("", isOn: $microMode)
					 .labelsHidden()
					 .toggleStyle(SwitchToggleStyle(tint: .gpGreen))
					 .scaleEffect(0.9)
					 .onChange(of: microMode) { oldValue, newValue in
						withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
						   expandedCardId = nil
						}
					 }
			   }
			}
		 }
		 .padding(.horizontal, 20)
		 
		 if !battlesMinimized {
			   // The poweredByBranding view should be placed here,
			   // directly below the main header HStack.
			poweredByBranding
			
			   // Sort by toggle and matchup cards grid follow
			sortByToggle
			
			matchupCardsGrid
		 } else {
			   // Minimized state - show summary
			minimizedBattlesSummary
		 }
	  }
   }
   
   private var minimizedBattlesSummary: some View {
	  HStack {
		 HStack(spacing: 16) {
			   // Quick stats
			HStack(spacing: 12) {
			   VStack(alignment: .leading, spacing: 2) {
				  Text("\(viewModel.myMatchups.count)")
					 .font(.system(size: 16, weight: .black))
					 .foregroundColor(.gpGreen)
				  Text("Battles")
					 .font(.system(size: 10, weight: .medium))
					 .foregroundColor(.gray)
			   }
			   
			   VStack(alignment: .leading, spacing: 2) {
				  Text("\(liveMatchupsCount)")
					 .font(.system(size: 16, weight: .black))
					 .foregroundColor(.blue)
				  Text("Live")
					 .font(.system(size: 10, weight: .medium))
					 .foregroundColor(.gray)
			   }
			   
			   VStack(alignment: .leading, spacing: 2) {
				  let winningCount = sortedMatchups.filter { getWinningStatusForMatchup($0) }.count
				  Text("\(winningCount)")
					 .font(.system(size: 16, weight: .black))
					 .foregroundColor(.gpGreen)
				  Text("Winning")
					 .font(.system(size: 10, weight: .medium))
					 .foregroundColor(.gray)
			   }
			}
		 
		 Spacer()
		 
		 Text("Tap to expand")
			.font(.system(size: 12, weight: .medium))
			.foregroundColor(.gray.opacity(0.7))
		 }
	  }
	  .padding(.horizontal, 20)
	  .padding(.vertical, 12)
	  .background(
		 RoundedRectangle(cornerRadius: 8)
			.fill(Color.black.opacity(0.3))
			.overlay(
			   RoundedRectangle(cornerRadius: 8)
				  .stroke(Color.gray.opacity(0.2), lineWidth: 1)
			)
	  )
	  .padding(.horizontal, 20)
	  .onTapGesture {
		 withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
			battlesMinimized = false
		 }
	  }
   }
   
   @ViewBuilder
   private var matchupCardsGrid: some View {
	  LazyVGrid(
		 columns: microMode ? 
		 [
			GridItem(.flexible(), spacing: 8),
			GridItem(.flexible(), spacing: 8),
			GridItem(.flexible(), spacing: 8),
			GridItem(.flexible(), spacing: 8)
		 ] :
			[
			   GridItem(.flexible(), spacing: 16),
			   GridItem(.flexible(), spacing: 16)
			],
		 spacing: microMode ? 8 : 16
	  ) {
		 ForEach(sortedMatchups, id: \.id) { matchup in
			MatchupCardViewBuilder(
			   matchup: matchup,
			   microMode: microMode,
			   expandedCardId: expandedCardId,
			   isWinning: getWinningStatusForMatchup(matchup),
			   onShowDetail: {
				  showingMatchupDetail = matchup
			   },
			   onMicroCardTap: { cardId in
				  handleMicroCardTap(cardId)
			   }
			)
		 }
	  }
	  .padding(.horizontal, 20)
	  .animation(.spring(response: 1.0, dampingFraction: 0.8), value: microMode)
	  .animation(.spring(response: 0.8, dampingFraction: 0.7), value: expandedCardId)
	  .animation(.spring(response: 0.6, dampingFraction: 0.8), value: sortByWinning)
	  .overlay(
		 // OVERLAY: Show expanded card over the entire grid when any card is expanded
		 Group {
			if let expandedId = expandedCardId,
			   let expandedMatchup = sortedMatchups.first(where: { $0.id == expandedId }) {
			   
			   Color.black.opacity(0.7) // Background dim
				  .ignoresSafeArea()
				  .onTapGesture {
					 withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
						expandedCardId = nil
					 }
				  }
			   
				  // Full-size expanded card in center
			   NonMicroCardView(
				  matchup: expandedMatchup,
				  isWinning: getWinningStatusForMatchup(expandedMatchup)
			   ) {
				  showingMatchupDetail = expandedMatchup
			   }
			   .frame(width: UIScreen.main.bounds.width * 0.6, height: 205) // 50% width, 20% taller than normal NM cards
			   .overlay(
				  RoundedRectangle(cornerRadius: 16)
					 .stroke(
						LinearGradient(
						   colors: [.gpGreen, .blue, .gpGreen],
						   startPoint: .topLeading,
						   endPoint: .bottomTrailing
						),
						lineWidth: 3
					 )
			   )
			   .zIndex(1000)
			   .onTapGesture(count: 2) {
				  withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
					 expandedCardId = nil
				  }
			   }
			}
		 }
	  )
   }
   
   private var poweredByBranding: some View {
	  VStack(spacing: 8) {
		 HStack(spacing: 8) {
			Image(systemName: "bolt.fill")
			   .font(.system(size: 12))
			   .foregroundColor(.gpGreen)
			
			Text("POWERED BY BIG WARROOM")
			   .font(.system(size: 12, weight: .black))
			   .foregroundStyle(
				  LinearGradient(
					 colors: [.gpGreen, .blue],
					 startPoint: .leading,
					 endPoint: .trailing
				  )
			   )
			
			Image(systemName: "bolt.fill")
			   .font(.system(size: 12))
			   .foregroundColor(.gpGreen)
		 }
		 
		 Text("The ultimate fantasy football command center")
			.font(.system(size: 10, weight: .medium))
			.foregroundColor(.gray)
	  }
	  .padding(.horizontal, 20)
	  .padding(.vertical, 12)
	  .background(
		 RoundedRectangle(cornerRadius: 12)
			.fill(Color.black.opacity(0.2))
			.overlay(
			   RoundedRectangle(cornerRadius: 12)
				  .stroke(
					 LinearGradient(
						colors: [.gpGreen.opacity(0.3), .blue.opacity(0.3)],
						startPoint: .leading,
						endPoint: .trailing
					 ),
					 lineWidth: 1
				  )
			)
	  )
   }
   
   private var sortByToggle: some View {
	  HStack {
		 Button(action: {
			withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
			   sortByWinning.toggle()
			}
		 }) {
			HStack(spacing: 8) {
			   Text("Sort by:")
				  .font(.system(size: 12, weight: .medium))
				  .foregroundColor(.white)
			   
			   Text(sortByWinning ? "WIN" : "LOSE")
				  .font(.system(size: 12, weight: .bold))
				  .foregroundColor(.white)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.background(
			   RoundedRectangle(cornerRadius: 8)
				  .fill(sortByWinning ? Color.gpGreen : Color.gpRedPink)
			)
		 }
		 
		 Spacer()
		 
			// Use existing PollingCountdownDial component
		 PollingCountdownDial(
			countdown: refreshCountdown,
			maxInterval: Double(AppConstants.MatchupRefresh),
			isPolling: viewModel.autoRefreshEnabled,
			onRefresh: {
			   Task {
				  await handlePullToRefresh()
			   }
			}
		 )
	  }
	  .padding(.horizontal, 20)
	  .padding(.bottom, 8)
	  .onAppear {
		 startCountdownTimer()
	  }
	  .onDisappear {
		 stopCountdownTimer()
	  }
   }
   
	  // MARK: -> Computed Properties
   
   private var sortedMatchups: [UnifiedMatchup] {
	  let matchups = viewModel.myMatchups
	  
	  if sortByWinning {
			// Sort by highest scores first (Win mode)
		 return matchups.sorted { matchup1, matchup2 in
			let score1 = matchup1.myTeam?.currentScore ?? 0
			let score2 = matchup2.myTeam?.currentScore ?? 0
			return score1 > score2
		 }
	  } else {
			// Sort by lowest scores first (Lose mode)
		 return matchups.sorted { matchup1, matchup2 in
			let score1 = matchup1.myTeam?.currentScore ?? 0
			let score2 = matchup2.myTeam?.currentScore ?? 0
			return score1 < score2
		 }
	  }
   }
   
   private var liveMatchupsCount: Int {
	  sortedMatchups.filter { matchup in
		 if matchup.isChoppedLeague {
			return false // Chopped leagues aren't "live" in the same sense
		 }
		 
		 guard let myTeam = matchup.myTeam else { return false }
		 let starters = myTeam.roster.filter { $0.isStarter }
		 return starters.contains { player in
			isPlayerInLiveGame(player)
		 }
	  }.count
   }
   
   private var currentNFLWeek: Int {
	  return selectedWeek // Use selected week instead of current NFL week
   }
   
   private var connectedLeaguesCount: Int {
	  Set(viewModel.myMatchups.map { $0.league.id }).count
   }
   
	  // MARK: -> Actions
   
   private func loadInitialData() {
	  Task {
		 // Load data for the initially selected week
		 if selectedWeek != NFLWeekService.shared.currentWeek {
			// If a different week is selected, load that specific week
			await viewModel.loadMatchupsForWeek(selectedWeek)
		 } else {
			// If current week is selected, use the normal load method
			await viewModel.loadAllMatchups()
		 }
	  }
   }
   
   private func handlePullToRefresh() async {
	  refreshing = true
	  await viewModel.manualRefresh()
	  refreshing = false
	  
		 // Reset countdown timer
	  refreshCountdown = Double(AppConstants.MatchupRefresh)
	  
		 // Force UI update after refresh
	  await MainActor.run {
			// This will trigger view refresh
	  }
   }
   
   private func timeAgo(_ date: Date) -> String {
	  let formatter = RelativeDateTimeFormatter()
	  formatter.unitsStyle = .abbreviated
	  return formatter.localizedString(for: date, relativeTo: Date())
   }
   
	  // MARK: -> Auto-refresh timer for Mission Control
   @State private var refreshTimer: Timer?
   
   private func startPeriodicRefresh() {
		 // Stop any existing timer first
	  stopPeriodicRefresh()
	  
		 // Start new timer - refresh every AppConstants.MatchupRefresh seconds when view is active
	  refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(AppConstants.MatchupRefresh), repeats: true) { _ in
		 Task { @MainActor in
			if UIApplication.shared.applicationState == .active && !viewModel.isLoading {
			   print("🔄 AUTO-REFRESH: Refreshing Mission Control data...")
			   await viewModel.manualRefresh()
			}
		 }
	  }
	  
	  print("🚀 TIMER: Started Mission Control auto-refresh (\(AppConstants.MatchupRefresh)s intervals)")
   }
   
   private func stopPeriodicRefresh() {
	  refreshTimer?.invalidate()
	  refreshTimer = nil
	  print("🛑 TIMER: Stopped Mission Control auto-refresh")
   }
   
	  // MARK: -> Countdown Timer
   
   private func startCountdownTimer() {
	  stopCountdownTimer()
	  
	  countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
		 refreshCountdown -= 1.0
		 
		 if refreshCountdown <= 0 {
			refreshCountdown = Double(AppConstants.MatchupRefresh) // Reset countdown
		 }
	  }
   }
   
   private func stopCountdownTimer() {
	  countdownTimer?.invalidate()
	  countdownTimer = nil
   }
   
	  // MARK: -> Micro Mode Actions
   
   private func handleMicroCardTap(_ cardId: String) {
	  withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
		 if expandedCardId == cardId {
			   // Collapse if already expanded
			expandedCardId = nil
		 } else {
			   // Expand this card (collapse any other)
			expandedCardId = cardId
		 }
	  }
   }
   
	  // Helper to get score color using same logic as MatchupCardView
   private func getScoreColorForMatchup(_ matchup: UnifiedMatchup) -> Color {
	  if matchup.isChoppedLeague {
			// For chopped leagues, use elimination status
		 guard let ranking = matchup.myTeamRanking else { return .white }
		 
		 switch ranking.eliminationStatus {
			case .champion, .safe:
			   return .gpGreen
			case .warning:
			   return .gpYellow
			case .danger:
			   return .orange
			case .critical, .eliminated:
			   return .gpRedPink
		 }
	  } else {
			// For regular matchups, use exact same logic as MatchupCardView compactTeamSection
		 guard let myTeam = matchup.myTeam, 
				  let opponentTeam = matchup.opponentTeam else {
			return .white
		 }
		 
		 let myScore = myTeam.currentScore ?? 0
		 let opponentScore = opponentTeam.currentScore ?? 0
		 
			// This is the EXACT logic from MatchupCardView
		 let isWinning = myScore > opponentScore
		 return isWinning ? .gpGreen : .gpRedPink
	  }
   }
   
	  // Get winning status using EXACT same logic as MatchupCardView
   private func getWinningStatusForMatchup(_ matchup: UnifiedMatchup) -> Bool {
	  if matchup.isChoppedLeague {
			// For chopped leagues, check if we're in good status
		 guard let teamRanking = matchup.myTeamRanking else { return false }
		 return teamRanking.eliminationStatus == .champion || teamRanking.eliminationStatus == .safe
	  } else {
			// For regular matchups - EXACT same logic as MatchupCardView
		 guard let myTeam = matchup.myTeam, 
				  let opponentTeam = matchup.opponentTeam else {
			return false
		 }
		 
		 let myScore = myTeam.currentScore ?? 0
		 let opponentScore = opponentTeam.currentScore ?? 0
		 
		 return myScore > opponentScore
	  }
   }
   
	  // MARK: -> Helper Functions for DUMB Micro Cards
   
   private func calculateWinPercentageString(for matchup: UnifiedMatchup) -> String {
	  if matchup.isChoppedLeague {
		 guard let teamRanking = matchup.myTeamRanking else { return "0%" }
		 return "\(Int(teamRanking.survivalProbability * 100))%"
	  }
	  
	  guard let myScore = matchup.myTeam?.currentScore,
			let opponentScore = matchup.opponentTeam?.currentScore else { return "50%" }
	  
	  let totalScore = myScore + opponentScore
	  if totalScore == 0 { return "50%" }
	  
	  let percentage = (myScore / totalScore) * 100.0
	  return "\(Int(percentage))%"
   }
   
   private func isMatchupLive(_ matchup: UnifiedMatchup) -> Bool {
	  guard let myTeam = matchup.myTeam else { return false }
	  let starters = myTeam.roster.filter { $0.isStarter }
	  return starters.contains { player in
		 isPlayerInLiveGame(player)
	  }
   }
   
   private func isPlayerInLiveGame(_ player: FantasyPlayer) -> Bool {
	  guard let gameStatus = player.gameStatus else { return false }
	  let timeString = gameStatus.timeString.lowercased()
	  
	  let quarterPatterns = ["1st ", "2nd ", "3rd ", "4th ", "ot ", "overtime"]
	  for pattern in quarterPatterns {
		 if timeString.contains(pattern) && timeString.contains(":") {
			return true
		 }
	  }
	  
	  let liveStatusIndicators = ["live", "halftime", "half", "end 1st", "end 2nd", "end 3rd", "end 4th"]
	  return liveStatusIndicators.contains { timeString.contains($0) }
   }
   
	  // MARK: -> New Helper Function
   
	  /// Identify which team is "me" using the same logic that determines isWinning
   private func identifyMyTeamInMatchup(_ matchup: UnifiedMatchup) -> (isMyTeamHome: Bool, myTeam: FantasyTeam?, opponentTeam: FantasyTeam?) {
	  if matchup.isChoppedLeague {
			// For chopped leagues, use the identified team from myTeamRanking
		 let myTeam = matchup.myTeam
		 return (true, myTeam, nil) // No opponent in chopped leagues
	  }
	  
	  guard let fantasyMatchup = matchup.fantasyMatchup else {
		 return (true, nil, nil)
	  }
	  
	  let homeTeam = fantasyMatchup.homeTeam
	  let awayTeam = fantasyMatchup.awayTeam
	  let homeScore = homeTeam.currentScore ?? 0
	  let awayScore = awayTeam.currentScore ?? 0
	  
		 // Use the SAME logic as getWinningStatusForMatchup to determine who's winning
	  let homeIsWinning = homeScore > awayScore
	  let isWinning = getWinningStatusForMatchup(matchup)
	  
		 // If I'm winning and home is winning, then I'm the home team
		 // If I'm winning and home is losing, then I'm the away team  
	  if isWinning == homeIsWinning {
			// I'm the home team
		 return (true, homeTeam, awayTeam)
	  } else {
			// I'm the away team
		 return (false, awayTeam, homeTeam)
	  }
   }
   
   // MARK: -> Week Picker Actions
   
   private func showWeekPicker() {
	  // Haptic feedback
	  let impactFeedback = UIImpactFeedbackGenerator(style: .light)
	  impactFeedback.impactOccurred()
	  
	  showingWeekPicker = true
   }
   
   private func onWeekSelected(_ week: Int) {
	  selectedWeek = week
	  
	  // Refresh data for the new week
	  Task {
		 await viewModel.loadMatchupsForWeek(week)
	  }
   }
}

   // MARK: -> Preview
#Preview {
   MatchupsHubView()
	  .preferredColorScheme(.dark)
}