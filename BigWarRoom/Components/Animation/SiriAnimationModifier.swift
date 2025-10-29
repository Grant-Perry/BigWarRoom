//
//  SiriAnimationModifier.swift
//  BigWarRoom
//
//  Dancing gradient animation modifier inspired by Siri interface
//  Designed for live updating views in BigWarRoom
//

import SwiftUI

// MARK: - Main Animation Modifier

/// **Siri Animation Modifier**
/// 
/// Creates a dynamic, dancing gradient background similar to Siri's interface.
/// Perfect for live updating views that need visual indication of real-time data.
///
/// **Usage Examples:**
/// ```swift
/// // Basic usage - always active
/// SomeView()
///     .siriAnimate()
///
/// // Property-controlled activation
/// HeaderView()
///     .siriAnimate(isActive: viewModel.isLiveUpdating)
///
/// // Custom intensity with loading state control
/// LiveScoreView()
///     .siriAnimate(
///         isActive: !viewModel.isLoading,
///         intensity: 0.4
///     )
///
/// // Full customization with state control
/// MissionControlView()
///     .siriAnimate(
///         isActive: dataManager.hasLiveData,
///         intensity: 0.8,
///         speed: 1.5,
///         baseColors: [.gpBlue, .gpGreen]
///     )
/// ```
///
/// **Recommended BigWarRoom Live View Patterns:**
/// - Mission Control: `isActive: missionControlViewModel.isLiveDataActive`
/// - Intelligence: `isActive: intelligenceViewModel.isRefreshing || intelligenceViewModel.hasRecentUpdate`
/// - All Live Players: `isActive: allLivePlayersViewModel.isLiveUpdating`
/// - Matchup Views: `isActive: matchupViewModel.gameInProgress`
/// - Real-time Components: `isActive: !viewModel.isLoading && viewModel.hasLiveConnection`
/// - Loading States: `isActive: viewModel.isLoading` (to indicate activity)
///
/// **Performance Benefits of Property Control:**
/// - Stops animation when data is stale (saves battery)
/// - Visual feedback for actual live activity
/// - Can indicate loading vs live vs idle states
/// - Perfect sync with your data refresh cycles
/// - Automatic pause during app backgrounding
struct SiriAnimationModifier: ViewModifier {
    
    // MARK: - Configuration
    
    /// Controls whether animation is running - binds to your view state
    let isActive: Bool
    
    /// Controls animation strength (0.0 = subtle, 1.0 = intense)
    let intensity: Double
    
    /// Controls animation speed (0.5 = slow, 2.0 = fast)
    let speed: Double
    
    /// Base colors for the gradient animation
    let baseColors: [Color]
    
    // MARK: - Animation State
    
    @State private var phase1: Double = 0
    @State private var phase2: Double = 0.33
    @State private var phase3: Double = 0.66
    @State private var morphState: Double = 0
    @State private var scaleState: Double = 1.0
    @State private var rotationState: Double = 0
    
    @State private var animationTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Initializer
    
    init(
        isActive: Bool = true,
        intensity: Double = 0.6,
        speed: Double = 1.0,
        baseColors: [Color] = [.blue, .purple, .pink, .orange, .green]
    ) {
        self.isActive = isActive
        self.intensity = max(0.0, min(1.0, intensity))
        self.speed = max(0.1, min(3.0, speed))
        self.baseColors = baseColors.isEmpty ? [.blue, .purple] : baseColors
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                // Only show gradient when active
                if isActive {
                    // Layered mesh gradients for depth and movement - EDGE FOCUSED
                    ZStack {
                        // Base layer - slower movement
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: baseMeshPoints,
                            colors: baseMeshColors
                        )
                        .scaleEffect(1.2) // Slightly larger to push to edges
                        .rotationEffect(.degrees(rotationState * 15 * intensity))
                        .opacity(0.25) // 🔥 More visible
                        .blur(radius: 40) // 🔥 More blur to soften edges
                        
                        // Mid layer - medium movement  
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: midMeshPoints,
                            colors: midMeshColors
                        )
                        .scaleEffect(1.1 + sin(morphState * 1.3) * 0.1 * intensity)
                        .rotationEffect(.degrees(-rotationState * 10 * intensity))
                        .opacity(0.2) // 🔥 More visible
                        .blur(radius: 50) // 🔥 Heavy blur
                        
                        // Top layer - fastest movement
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: topMeshPoints,
                            colors: topMeshColors
                        )
                        .scaleEffect(scaleState * 1.1)
                        .rotationEffect(.degrees(rotationState * 5 * intensity))
                        .opacity(0.15) // 🔥 More visible
                        .blur(radius: 60) // 🔥 Maximum blur for edge effect
                    }
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .onAppear {
                if isActive && scenePhase == .active {
                    startAnimation()
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue && scenePhase == .active {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    if isActive {
                        startAnimation()
                    }
                case .background, .inactive:
                    stopAnimation()
                @unknown default:
                    break
                }
            }
            .animation(.easeInOut(duration: 0.4), value: isActive)
    }
    
    // MARK: - Mesh Point Calculations
    
    private var baseMeshPoints: [SIMD2<Float>] {
        let wave1 = Float(sin(phase1) * 0.3 * intensity)
        let wave2 = Float(cos(phase1 * 1.2) * 0.25 * intensity)
        let wave3 = Float(sin(phase1 * 0.8) * 0.2 * intensity)
        
        return [
            SIMD2(0.0 + wave1, 0.0 + wave2),
            SIMD2(0.5 + wave3, 0.0 + wave1),
            SIMD2(1.0 + wave2, 0.0 + wave3),
            SIMD2(0.0 + wave2, 0.5 + wave3),
            SIMD2(0.5 + wave1, 0.5 + wave2),
            SIMD2(1.0 + wave3, 0.5 + wave1),
            SIMD2(0.0 + wave3, 1.0 + wave1),
            SIMD2(0.5 + wave2, 1.0 + wave3),
            SIMD2(1.0 + wave1, 1.0 + wave2)
        ]
    }
    
    private var midMeshPoints: [SIMD2<Float>] {
        let wave1 = Float(sin(phase2 + 0.5) * 0.4 * intensity)
        let wave2 = Float(cos(phase2 * 1.5) * 0.3 * intensity)
        let wave3 = Float(sin(phase2 * 0.7) * 0.35 * intensity)
        
        return [
            SIMD2(0.0 + wave2, 0.0 + wave3),
            SIMD2(0.5 + wave1, 0.0 + wave2),
            SIMD2(1.0 + wave3, 0.0 + wave1),
            SIMD2(0.0 + wave1, 0.5 + wave2),
            SIMD2(0.5 + wave3, 0.5 + wave1),
            SIMD2(1.0 + wave2, 0.5 + wave3),
            SIMD2(0.0 + wave3, 1.0 + wave2),
            SIMD2(0.5 + wave1, 1.0 + wave1),
            SIMD2(1.0 + wave2, 1.0 + wave3)
        ]
    }
    
    private var topMeshPoints: [SIMD2<Float>] {
        let wave1 = Float(sin(phase3 + 1.0) * 0.25 * intensity)
        let wave2 = Float(cos(phase3 * 1.8) * 0.35 * intensity)
        let wave3 = Float(sin(phase3 * 1.1) * 0.3 * intensity)
        
        return [
            SIMD2(0.0 + wave3, 0.0 + wave1),
            SIMD2(0.5 + wave2, 0.0 + wave3),
            SIMD2(1.0 + wave1, 0.0 + wave2),
            SIMD2(0.0 + wave2, 0.5 + wave1),
            SIMD2(0.5 + wave1, 0.5 + wave3),
            SIMD2(1.0 + wave3, 0.5 + wave2),
            SIMD2(0.0 + wave1, 1.0 + wave3),
            SIMD2(0.5 + wave3, 1.0 + wave2),
            SIMD2(1.0 + wave2, 1.0 + wave1)
        ]
    }
    
    // MARK: - Color Calculations
    
    private var baseMeshColors: [Color] {
        let colorCount = baseColors.count
        var colors: [Color] = []
        
        for i in 0..<9 {
            let baseIndex = i % colorCount
            let nextIndex = (i + 1) % colorCount
            let blend = sin(phase1 + Double(i) * 0.5) * 0.5 + 0.5
            
            let baseColor = baseColors[baseIndex]
            let nextColor = baseColors[nextIndex]
            
            colors.append(Color(
                red: interpolate(baseColor.rgbComponents.red, nextColor.rgbComponents.red, blend),
                green: interpolate(baseColor.rgbComponents.green, nextColor.rgbComponents.green, blend),
                blue: interpolate(baseColor.rgbComponents.blue, nextColor.rgbComponents.blue, blend)
            ))
        }
        
        return colors
    }
    
    private var midMeshColors: [Color] {
        let colorCount = baseColors.count
        var colors: [Color] = []
        
        for i in 0..<9 {
            let baseIndex = (i + 2) % colorCount
            let nextIndex = (i + 3) % colorCount
            let blend = cos(phase2 + Double(i) * 0.7) * 0.5 + 0.5
            
            let baseColor = baseColors[baseIndex]
            let nextColor = baseColors[nextIndex]
            
            colors.append(Color(
                red: interpolate(baseColor.rgbComponents.red, nextColor.rgbComponents.red, blend),
                green: interpolate(baseColor.rgbComponents.green, nextColor.rgbComponents.green, blend),
                blue: interpolate(baseColor.rgbComponents.blue, nextColor.rgbComponents.blue, blend)
            ))
        }
        
        return colors
    }
    
    private var topMeshColors: [Color] {
        let colorCount = baseColors.count
        var colors: [Color] = []
        
        for i in 0..<9 {
            let baseIndex = (i + 4) % colorCount
            let nextIndex = (i + 5) % colorCount
            let blend = sin(phase3 + Double(i) * 0.3) * 0.5 + 0.5
            
            let baseColor = baseColors[baseIndex]
            let nextColor = baseColors[nextIndex]
            
            colors.append(Color(
                red: interpolate(baseColor.rgbComponents.red, nextColor.rgbComponents.red, blend),
                green: interpolate(baseColor.rgbComponents.green, nextColor.rgbComponents.green, blend),
                blue: interpolate(baseColor.rgbComponents.blue, nextColor.rgbComponents.blue, blend)
            ))
        }
        
        return colors
    }
    
    // MARK: - Animation Control
    
    private func startAnimation() {
        stopAnimation() // Ensure no duplicate timers
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            let deltaTime = 1.0/60.0 * speed
            
            phase1 += deltaTime * 2.0
            phase2 += deltaTime * 1.7
            phase3 += deltaTime * 2.3
            
            morphState = sin(phase1 * 0.5) * 0.5 + 0.5
            scaleState = 1.0 + sin(phase2 * 0.8) * 0.1 * intensity
            rotationState += deltaTime * 10
            
            // Keep phases in reasonable range
            if phase1 > .pi * 4 { phase1 -= .pi * 4 }
            if phase2 > .pi * 4 { phase2 -= .pi * 4 }
            if phase3 > .pi * 4 { phase3 -= .pi * 4 }
            if rotationState > 360 { rotationState -= 360 }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    // MARK: - Utility Functions
    
    private func interpolate(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
}

// MARK: - Color Extension for Component Access (using unique name to avoid conflicts)

private extension Color {
    var rgbComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
        #else
        // Fallback for macOS
        return (0.5, 0.5, 0.5, 1.0)
        #endif
    }
}
