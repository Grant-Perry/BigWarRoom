//
//  View+Badge.swift
//  BigWarRoom
//
//  View extension for iOS notification badges - DRY and reusable across the platform
//

import SwiftUI

extension View {

	  /// **Apply Siri-style Dancing Gradient Animation with State Control**
	  ///
	  /// Adds a dynamic, flowing gradient background similar to Siri's interface.
	  /// Perfect for live updating views that need visual indication of real-time data.
	  /// Now with property-based control for precise animation timing!
	  ///
	  /// **Parameters:**
	  /// - `isActive`: Controls animation state - Default: true (always on)
	  /// - `intensity`: Animation strength (0.0 = subtle, 1.0 = intense) - Default: 0.6
	  /// - `speed`: Animation speed multiplier (0.5 = slow, 2.0 = fast) - Default: 1.0
	  /// - `baseColors`: Colors to use in the gradient - Default: [blue, purple, pink, orange, green]
	  ///
	  /// **Basic Usage Examples:**
	  /// ```swift
	  /// // Always active (classic behavior)
	  /// HeaderView()
	  ///     .siriAnimate()
	  ///
	  /// // Property-controlled activation
	  /// LiveDataView()
	  ///     .siriAnimate(isActive: viewModel.hasLiveConnection)
	  ///
	  /// // Subtle effect for backgrounds
	  /// ContentView()
	  ///     .siriAnimate(isActive: !viewModel.isLoading, intensity: 0.3)
	  ///
	  /// // Fast pulsing during updates
	  /// RefreshingView()
	  ///     .siriAnimate(isActive: viewModel.isRefreshing, speed: 2.0)
	  /// ```
	  ///
	  /// **BigWarRoom Live View Integration:**
	  /// ```swift
	  /// // Mission Control - animate when live data is flowing
	  /// MissionControlView()
	  ///     .siriAnimate(
	  ///         isActive: missionControlViewModel.isLiveDataActive,
	  ///         intensity: 0.8,
	  ///         baseColors: [.gpBlue, .gpGreen]
	  ///     )
	  ///
	  /// // Intelligence - pulse during refresh cycles
	  /// IntelligenceView()
	  ///     .siriAnimate(
	  ///         isActive: intelligenceViewModel.isRefreshing || intelligenceViewModel.hasRecentUpdate,
	  ///         intensity: 0.6,
	  ///         speed: 1.2
	  ///     )
	  ///
	  /// // All Live Players - indicate real-time updates
	  /// AllLivePlayersView()
	  ///     .siriAnimate(
	  ///         isActive: allLivePlayersViewModel.isLiveUpdating && !allLivePlayersViewModel.isLoading,
	  ///         intensity: 0.4,
	  ///         speed: 0.8
	  ///     )
	  ///
	  /// // Matchup Views - active during game time
	  /// MatchupView()
	  ///     .siriAnimate(
	  ///         isActive: matchupViewModel.gameInProgress,
	  ///         intensity: 0.5,
	  ///         baseColors: [.gpOrange, .gpRedPink]
	  ///     )
	  ///
	  /// // Loading States - indicate activity
	  /// LoadingView()
	  ///     .siriAnimate(
	  ///         isActive: viewModel.isLoading,
	  ///         speed: 1.5,
	  ///         baseColors: [.gray, .blue]
	  ///     )
	  /// ```
	  ///
	  /// **Advanced State Patterns:**
	  /// ```swift
	  /// // Multiple conditions
	  /// .siriAnimate(isActive: !viewModel.isLoading && viewModel.hasLiveData && viewModel.connectionActive)
	  ///
	  /// // Different intensities based on state
	  /// .siriAnimate(
	  ///     isActive: true,
	  ///     intensity: viewModel.isHighActivity ? 0.8 : 0.3
	  /// )
	  ///
	  /// // Speed changes based on update frequency
	  /// .siriAnimate(
	  ///     isActive: viewModel.isLive,
	  ///     speed: viewModel.updateFrequency > 5 ? 2.0 : 1.0
	  /// )
	  /// ```
	  ///
	  /// **Performance Benefits:**
	  /// - ✅ Animation only runs when `isActive: true`
	  /// - ✅ Automatically pauses when app backgrounds
	  /// - ✅ Smooth transitions when state changes
	  /// - ✅ Perfect sync with your data refresh cycles
	  /// - ✅ Visual feedback for actual live activity vs idle state
	  /// - ✅ Battery optimization when animation not needed
	  /// - ✅ 60fps Metal-accelerated rendering when active
	  ///
	  /// **State Management Tips:**
	  /// - Use `!viewModel.isLoading` to hide during initial loads
	  /// - Use `viewModel.hasLiveConnection` for real-time data indication
	  /// - Combine states: `viewModel.isLive && !viewModel.isPaused`
	  /// - Different colors for different states (loading vs live vs error)
   func siriAnimate(
	  isActive: Bool = true,
	  intensity: Double = 0.6,
	  speed: Double = 1.0,
	  baseColors: [Color] = [.blue, .purple, .pink, .orange, .green]
   ) -> some View {
	  self.modifier(
		 SiriAnimationModifier(
			isActive: isActive,
			intensity: intensity,
			speed: speed,
			baseColors: baseColors
		 )
	  )
   }


    /// Apply iOS notification badge matching Apple's official specifications
    /// - Parameters:
    ///   - count: The number to display in the badge
    ///   - xOffset: Horizontal offset from the view's trailing edge (default: 4)
    ///   - yOffset: Vertical offset from the view's top edge (default: -8)
    ///   - badgeColor: Badge background color (default: Apple's system red #FF3B30)
    /// - Returns: View with badge overlay
   func notificationBadge(count: Int, xOffset: CGFloat = 4, yOffset: CGFloat = -8, badgeColor: Color = .gpRedPink) -> some View {
        ZStack(alignment: .topTrailing) {
            self
            
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .default))
					.kerning(-0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, count >= 10 ? 6 : 4) // More padding for 2+ digits
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(badgeColor) // Apple's system red #FF3B30
                    )
                    .frame(minWidth: 20, minHeight: 20) // Minimum 20px as per Apple specs
                    .offset(x: xOffset, y: yOffset)
            }
        }
    }
}

#Preview("Badge Extension Examples") {
    VStack(spacing: 40) {
        HStack(spacing: 40) {
            // Examples with different counts - matching iOS specs
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 3)
            
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 16)
            
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 142)
            
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .notificationBadge(count: 400)
        }
        
        HStack(spacing: 40) {
            // Test with text elements
            Text("Mission Control")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .notificationBadge(count: 16, xOffset: 4, yOffset: -8)
            
            Text("All Rostered Players")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
				.notificationBadge(count: 146, xOffset: 24, yOffset: -8)
        }
    }
    .padding()
    .background(Color.black)
}
