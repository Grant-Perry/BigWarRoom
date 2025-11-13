//
//  CurrentLineupAnalysisView.swift
//  BigWarRoom
//
//  Current Lineup Analysis section for Lineup RX
//

import SwiftUI

struct CurrentLineupAnalysisView: View {
    let result: LineupOptimizerService.OptimizationResult
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(icon: "chart.bar.fill", title: "Current Lineup Analysis", color: .gpBlue)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gpBlue)
                }
            }
            
            if isExpanded {
                // Show congratulatory badge if lineup is already optimized
                if result.improvement <= 0.1 {
                    OptimizedLineupBadge()
                }
                
                HStack(spacing: 20) {
                    StatCard(
                        title: "Current Score",
                        value: String(format: "%.1f", result.currentPoints),
                        color: .white
                    )
                    
                    StatCard(
                        title: "Optimal Score",
                        value: String(format: "%.1f", result.projectedPoints),
                        color: .gpGreen
                    )
                    
                    StatCard(
                        title: "Improvement",
                        value: String(format: "+%.1f", result.improvement),
                        color: result.improvement > 0 ? .gpGreen : .gray
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct OptimizedLineupBadge: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.gpGreen, .gpGreen.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("🎯 Lineup Optimized!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("Your lineup is already at maximum projected points")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gpGreen.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gpGreen.opacity(0.4), lineWidth: 2)
                )
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
}

struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}