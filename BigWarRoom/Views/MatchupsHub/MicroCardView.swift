//
//  MicroCardView.swift
//  BigWarRoom
//
//  DUMB micro card - just displays passed data, no lookups or calculations
//

import SwiftUI

struct MicroCardView: View {
    // DUMB parameters - all data passed in
    let leagueName: String
    let avatarURL: String?
    let managerName: String
    let score: String
    let scoreColor: Color
    let percentage: String
    let borderColors: [Color]
    let borderWidth: CGFloat
    let borderOpacity: Double
    let shouldPulse: Bool
    let shadowColor: Color
    let shadowRadius: CGFloat
    let onTap: () -> Void
    
    // 🔥 NEW: Eliminated status parameters (renamed from chopped)
    let isEliminated: Bool
    let eliminationWeek: Int?
    
    @State private var pulseOpacity: Double = 0.3
    @State private var glowIntensity: Double = 0.0
    @State private var eliminatedPulse: Bool = false
    
    // NEW: Customizable card gradient color
    private let cardGrad: Color = .rockiesPrimary
    
    // Initializer with all parameters including new eliminated ones
    init(
        leagueName: String,
        avatarURL: String?,
        managerName: String,
        score: String,
        scoreColor: Color,
        percentage: String,
        borderColors: [Color],
        borderWidth: CGFloat,
        borderOpacity: Double,
        shouldPulse: Bool,
        shadowColor: Color,
        shadowRadius: CGFloat,
        onTap: @escaping () -> Void,
        isEliminated: Bool = false,
        eliminationWeek: Int? = nil
    ) {
        self.leagueName = leagueName
        self.avatarURL = avatarURL
        self.managerName = managerName
        self.score = score
        self.scoreColor = scoreColor
        self.percentage = percentage
        self.borderColors = borderColors
        self.borderWidth = borderWidth
        self.borderOpacity = borderOpacity
        self.shouldPulse = shouldPulse
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.onTap = onTap
        self.isEliminated = isEliminated
        self.eliminationWeek = eliminationWeek
    }
    
    var body: some View {
        Button(action: onTap) {
            // 🔥 SIMPLIFIED: No overlay needed - eliminated state is built into the card content
            baseCardContent
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if shouldPulse {
                startPulseAnimation()
            }
            if isEliminated {
                startEliminatedAnimation()
            }
        }
    }
    
    // MARK: -> Base Card Content
    
    private var baseCardContent: some View {
        VStack(spacing: 8) {
            // League name
            Text(leagueName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isEliminated ? .gray.opacity(0.6) : .gray)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
            
            // 🔥 CONDITIONAL CONTENT: Show eliminated OR regular content (same structure)
            if isEliminated {
                eliminatedContentStructure
            } else {
                regularContentStructure
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .shadow(
            color: isEliminated ? Color.black.opacity(0.5) : shadowColor,
            radius: shadowRadius,
            x: 0,
            y: 2
        )
    }
    
    // MARK: -> Eliminated Content Structure (mirrors regular structure)
    
    private var eliminatedContentStructure: some View {
        VStack(spacing: 6) {
            // Avatar replacement - skull icon
            Circle()
                .fill(Color.red.opacity(0.3))
                .overlay(
                    Text("☠️")
                        .font(.system(size: 18))
                        .scaleEffect(eliminatedPulse ? 1.1 : 1.0)
                )
                .frame(width: 36, height: 36)
            
            // Manager name replacement - ELIMINATED
            Text("ELIMINATED")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white)
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Score/Percentage replacement - Week info
            VStack(spacing: 4) {
                if let week = eliminationWeek {
                    Text("Week \(week)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.red)
                }
                
                // Manager name
                Text(managerName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
    
    // MARK: -> Regular Content Structure  
    
    private var regularContentStructure: some View {
        VStack(spacing: 6) {
            // Avatar
            if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(scoreColor.opacity(0.6))
                        .overlay(
                            Text(String(managerName.prefix(2)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(scoreColor.opacity(0.6))
                    .overlay(
                        Text(String(managerName.prefix(2)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .frame(width: 36, height: 36)
            }
            
            // Manager name
            Text(managerName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Score + Percentage
            VStack(spacing: 4) {
                Text(score)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
                
                Text(percentage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: -> Card Background
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundGradient)
            .overlay(highlightOverlay)
            .overlay(darkenOverlay)
            .overlay(borderOverlay)
    }
    
    private var backgroundGradient: LinearGradient {
        if isEliminated {
            // 🔥 ELIMINATED GRADIENT: Use gpRedPink
            return LinearGradient(
                colors: [Color.gpRedPink.opacity(0.8), Color.black.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Regular purple gradient
            return LinearGradient(
                colors: [cardGrad.opacity(0.6), cardGrad.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(isEliminated ? 0.05 : 0.15), Color.clear, Color.white.opacity(isEliminated ? 0.02 : 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var darkenOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(isEliminated ? 0.3 : 0.3))
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                LinearGradient(
                    colors: isEliminated ? [.red, .black, .red] : borderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isEliminated ? 2.0 : borderWidth
            )
            .opacity(shouldPulse ? pulseOpacity : borderOpacity)
    }
    
    // MARK: -> Animations
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.8
            glowIntensity = 0.8
        }
    }
    
    private func startEliminatedAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            eliminatedPulse = true
        }
    }
}