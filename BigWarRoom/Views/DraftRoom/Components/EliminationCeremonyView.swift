//
//  EliminationCeremonyView.swift
//  BigWarRoom
//
//  🎬💀 ELIMINATION CEREMONY VIEW 💀🎬
//  The dramatic final moment - torch extinguishing ceremony
//

import SwiftUI

/// **EliminationCeremonyView**
/// 
/// The most dramatic moment in Chopped - the elimination ceremony featuring:
/// - Dark ceremonial background with flickering torch effects
/// - Dramatic delayed reveal of the eliminated contestant
/// - Grayscale death treatment of eliminated team avatar
/// - Death skull overlay and red border effects
/// - Torch extinguishing button to dismiss
struct EliminationCeremonyView: View {
    let eliminatedTeam: FantasyTeamRanking?
    let week: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var showElimination = false
    @State private var torchFlicker = false
    
    var body: some View {
        ZStack {
            // Dark ceremonial background
            Color.black.ignoresSafeArea()
            
            // Flickering torch effect
            flickeringTorchBackground
            
            VStack(spacing: 30) {
                // Ceremony header
                ceremonyHeader
                
                // Dramatic reveal
                if let eliminated = eliminatedTeam, showElimination {
                    eliminationReveal(eliminated: eliminated)
                }
                
                Spacer()
                
                // Torch extinguishing button
                torchExtinguishButton
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            startCeremonyAnimations()
        }
    }
    
    // MARK: - Component Views
    
    private var flickeringTorchBackground: some View {
        LinearGradient(
            colors: [.orange.opacity(0.1), .red.opacity(0.1), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .opacity(torchFlicker ? 0.3 : 0.1)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: torchFlicker)
    }
    
    private var ceremonyHeader: some View {
        VStack(spacing: 16) {
            Text("🎬")
                .font(.system(size: 48))
            
            Text("ELIMINATION CEREMONY")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.red)
                .tracking(3)
            
            Text("WEEK \(week)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .tracking(2)
        }
    }
    
    private func eliminationReveal(eliminated: FantasyTeamRanking) -> some View {
        VStack(spacing: 20) {
            Text("THE CHOPPED CONTESTANT...")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.orange)
                .tracking(2)
            
            // Eliminated team display
            VStack(spacing: 16) {
                // Team avatar with death effect
                eliminatedTeamAvatar(eliminated: eliminated)
                
                Text(eliminated.team.ownerName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.red)
                    .strikethrough()
                
                Text("FINAL SCORE: \(eliminated.weeklyPointsString)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("\"Your journey ends here.\"")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .italic()
            }
            .padding(.vertical, 20)
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func eliminatedTeamAvatar(eliminated: FantasyTeamRanking) -> some View {
        Group {
            if let avatarURL = eliminated.team.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(Color.gray)
                    }
                }
            } else {
                Circle()
                    .fill(eliminated.team.espnTeamColor)
                    .overlay(
                        Text(eliminated.team.teamInitials)
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .grayscale(1.0)
        .overlay(
            Circle()
                .stroke(Color.red, lineWidth: 4)
        )
        .overlay(
            Text("💀")
                .font(.system(size: 40))
                .offset(x: 40, y: -40)
        )
    }
    
    private var torchExtinguishButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack {
                Text("🕯️")
                Text("EXTINGUISH THE TORCH")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.red.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.orange, lineWidth: 2)
                    )
            )
        }
    }
    
    // MARK: - Animation Logic
    
    private func startCeremonyAnimations() {
        torchFlicker = true
        
        // Dramatic delay before revealing elimination
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 1.0)) {
                showElimination = true
            }
        }
    }
}