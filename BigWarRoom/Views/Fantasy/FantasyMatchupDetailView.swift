   //
   //  FantasyMatchupDetailView.swift
   //  BigWarRoom
   //
   //  Detailed view for a specific fantasy matchup showing active rosters
   //  Refactored with proper MVVM architecture and modular components
   //

import SwiftUI

   /// Main view for displaying detailed fantasy matchup information
struct FantasyMatchupDetailView: View {
   let matchup: FantasyMatchup
   let leagueName: String
   var fantasyViewModel: FantasyViewModel? = nil
   let logoSize: CGFloat = 32
   @Environment(\.dismiss) private var dismiss

	  // Shared instance to ensure stats are loaded early
   @ObservedObject private var livePlayersViewModel = AllLivePlayersViewModel.shared

	  // Sorting state for matchup details
   @State private var sortingMethod: MatchupSortingMethod = .position
   @State private var sortHighToLow = false // Position: A-Z, Score: High-Low by default

	  // MARK: - Initializers

	  /// Default initializer for backward compatibility
   init(matchup: FantasyMatchup, leagueName: String) {
	  self.matchup = matchup
	  self.leagueName = leagueName
	  self.fantasyViewModel = nil
   }

	  /// Full initializer with FantasyViewModel
   init(matchup: FantasyMatchup, fantasyViewModel: FantasyViewModel, leagueName: String) {
	  self.matchup = matchup
	  self.leagueName = leagueName
	  self.fantasyViewModel = fantasyViewModel
   }

	  // MARK: - Body

   var body: some View {
	  let awayTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 0) ?? matchup.awayTeam.currentScore ?? 0.0
	  let homeTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 1) ?? matchup.homeTeam.currentScore ?? 0.0
	  let awayTeamIsWinning = awayTeamScore > homeTeamScore
	  let homeTeamIsWinning = homeTeamScore > awayTeamScore

	  VStack(spacing: 0) {
			// Header with navigation and countdown
		 navigationHeader

			// Matchup details title
		 matchupDetailsTitle

			// Fantasy detail header with team comparison
		 FantasyDetailHeaderView(
			leagueName: leagueName,
			matchup: matchup,
			awayTeamIsWinning: awayTeamIsWinning,
			homeTeamIsWinning: homeTeamIsWinning,
			fantasyViewModel: fantasyViewModel,
			sortingMethod: sortingMethod,
			sortHighToLow: sortHighToLow,
			onSortingMethodChanged: { method in
			   withAnimation(.easeInOut(duration: 0.3)) {
				  sortingMethod = method
					 // Reset sort direction to logical default for each method
				  sortHighToLow = (method == .score) // Score: High-Low, others: A-Z
			   }
			},
			onSortDirectionChanged: {
			   withAnimation(.easeInOut(duration: 0.3)) {
				  sortHighToLow.toggle()
			   }
			}
		 )
		 .padding(.horizontal, 16) // Standard horizontal padding
		 .padding(.top, 16) // More top spacing from "Matchup Details"
		 .padding(.bottom, 20) // More bottom spacing before "Active Roster"

			// Roster content
		 rosterScrollView
	  }
	  .navigationBarHidden(true)
	  .navigationBarBackButtonHidden(true)
	  .preferredColorScheme(.dark)
	  .background(Color.black)
	  .onAppear {
		 handleViewAppearance()
	  }
	  .task {
		 await handleViewTask()
	  }
   }

	  // MARK: - View Components

   private var navigationHeader: some View {
	  HStack {
		 Button(action: {
			dismiss()
		 }) {
			Image(systemName: "chevron.left")
			   .font(.system(size: 18, weight: .medium))
			   .foregroundColor(.white)
			   .frame(width: 44, height: 44)
			   .background(Color.gray.opacity(0.2))
			   .clipShape(Circle())
		 }

		 Spacer()

			// League name and week info with platform logo
		 VStack(spacing: 2) {
			HStack(spacing: 8) {
				  // Platform logo based on league source - CUSTOM SIZED LOGOS
			   if let selectedLeague = fantasyViewModel?.selectedLeague {
				  Group {
					 switch selectedLeague.source {
						case .sleeper:
							  // CUSTOM Sleeper logo that respects our size
						   Image("sleeperLogo")
							  .resizable()
							  .scaledToFit()

						case .espn:
							  // CUSTOM ESPN logo that respects our size
						   Image("espnLogo")
							  .resizable()
							  .scaledToFit()
					 }
				  }
				  .frame(width: logoSize, height: logoSize) // This will now work properly
			   }

			   Text(leagueName)
				  .font(.system(size: 20, weight: .bold))
				  .foregroundColor(.white)
				  .lineLimit(1)
			}

			Text("Week \(fantasyViewModel?.selectedWeek ?? matchup.week)")
			   .font(.system(size: 16, weight: .semibold))
			   .italic()
			   .foregroundColor(.gray)
		 }

		 Spacer()

			// Circular countdown timer
		 RefreshCountdownTimerView()
	  }
	  .padding(.horizontal)
	  .padding(.top, 8)
	  .onAppear {
			// DEBUG: Help troubleshoot the logo issue
		 print("🐛 NavigationHeader - fantasyViewModel: \(fantasyViewModel != nil ? "exists" : "nil")")
		 if let selectedLeague = fantasyViewModel?.selectedLeague {
			print("🐛 NavigationHeader - Selected league source: \(selectedLeague.source.rawValue)")
		 } else {
			print("🐛 NavigationHeader - No selected league available")
		 }
	  }
   }

   private var matchupDetailsTitle: some View {
	  HStack {
		 Text("Matchup Details")
			.font(.title2)
			.fontWeight(.bold)

		 Spacer()
	  }
	  .padding(.horizontal)
	  .padding(.top, 12) // Added top padding
	  .padding(.bottom, 4) // Added bottom padding for separation
   }

   private var rosterScrollView: some View {
	  ScrollView {
		 VStack(spacing: 16) {
			if let viewModel = fantasyViewModel {
			   viewModel.activeRosterSectionSorted(matchup: matchup, sortMethod: sortingMethod, highToLow: sortHighToLow)
			   viewModel.benchSectionSorted(matchup: matchup, sortMethod: sortingMethod, highToLow: sortHighToLow)
			} else {
				  // Fallback content when no view model is available
			   simplifiedRosterView
			}
		 }
		 .padding(.top, 8)
	  }
	  .background(Color(.systemGroupedBackground).ignoresSafeArea())
   }

	  // MARK: - Simplified Roster View (Fallback)

	  /// Simplified roster view for when no FantasyViewModel is available
   private var simplifiedRosterView: some View {
	  VStack(spacing: 16) {
			// HOME team roster first
		 VStack(alignment: .leading, spacing: 8) {
			Text("\(matchup.homeTeam.name) Roster")
			   .font(.headline)
			   .foregroundColor(.white)
			   .padding(.horizontal)

			LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
			   ForEach(matchup.homeTeam.roster.filter { $0.isStarter }) { player in
				  FantasyPlayerCard(
					 player: player,
					 fantasyViewModel: fantasyViewModel ?? FantasyViewModel.shared,
					 matchup: matchup,
					 teamIndex: 1, // Home team index
					 isBench: false
				  )
				  .padding(.horizontal)
			   }
			}
		 }

			// AWAY team roster second
		 VStack(alignment: .leading, spacing: 8) {
			Text("\(matchup.awayTeam.name) Roster")
			   .font(.headline)
			   .foregroundColor(.white)
			   .padding(.horizontal)

			LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
			   ForEach(matchup.awayTeam.roster.filter { $0.isStarter }) { player in
				  FantasyPlayerCard(
					 player: player,
					 fantasyViewModel: fantasyViewModel ?? FantasyViewModel.shared,
					 matchup: matchup,
					 teamIndex: 0, // Away team index
					 isBench: false
				  )
				  .padding(.horizontal)
			   }
			}
		 }
	  }
   }

	  // MARK: - Private Methods

   private func handleViewAppearance() {
		 // Always load stats when this view appears
	  print("🏈 FantasyMatchupDetailView onAppear - forcing stats load")
	  Task {
		 await livePlayersViewModel.forceLoadStats()
	  }
   }

   private func handleViewTask() async {
		 // Aggressive stats loading for Mission Control navigation
	  print("🏈 FantasyMatchupDetailView task - checking stats state")
	  print("📊 Stats loaded: \(livePlayersViewModel.statsLoaded)")
	  print("👥 Player stats count: \(livePlayersViewModel.playerStats.keys.count)")

		 // Always ensure we have stats - don't rely on statsLoaded flag alone
	  if livePlayersViewModel.playerStats.isEmpty {
		 print("⚠️ No player stats found - forcing full reload")
		 await livePlayersViewModel.loadAllPlayers()
	  } else {
		 print("✅ Player stats already available - refreshing to ensure latest data")
		 await livePlayersViewModel.forceLoadStats()
	  }
   }
}
